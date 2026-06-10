import Foundation
import Combine
import SwiftUI
import UIKit
import Photos
import GardenCore

enum Season: String, CaseIterable, Comparable {
    case spring = "Spring" // Mar–May
    case summer = "Summer" // Jun–Aug
    case fall = "Fall"     // Sep–Nov
    case winter = "Winter" // Dec–Feb

    static func from(date: Date) -> Season {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 3...5: return .spring
        case 6...8: return .summer
        case 9...11: return .fall
        default: return .winter
        }
    }

    static func < (lhs: Season, rhs: Season) -> Bool {
        let order: [Season] = [.spring, .summer, .fall, .winter]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

struct SeasonGroup: Identifiable {
    let id = UUID()
    let season: Season
    let sections: [DaySection]
}

struct YearGroup: Identifiable {
    let id: Int
    let seasons: [SeasonGroup]
}

enum PinnedItem: Identifiable {
    case moment(Moment, [Moment])
    case prompt(PromptMemory)
    
    var id: UUID {
        switch self {
        case .moment(let m, _): return m.id
        case .prompt(let p): return p.id
        }
    }
    
    var date: Date {
        switch self {
        case .moment(let m, _): return m.dateTaken
        case .prompt(let p): return p.date
        }
    }
    
    var pinnedAt: Date {
        switch self {
        case .moment(let m, _): return m.pinnedAt ?? Date.distantPast
        case .prompt(let p): return p.pinnedAt ?? Date.distantPast
        }
    }
    
    var title: String? {
        switch self {
        case .moment(let m, _): return m.promptText
        case .prompt(let p): return p.promptText
        }
    }
    
    var placeName: String? {
        switch self {
        case .moment(let m, _): return m.placeName
        case .prompt(let p): return p.placeName
        }
    }
    
    var slides: [PinnedSlide] {
        switch self {
        case .moment(_, let all):
            return all.map { PinnedSlide(id: $0.id, image: $0.thumbnail, isLocked: $0.isLocked, unlockTime: $0.unlockTime) }
        case .prompt(let p):
            return p.photos.map { ph in
                let isLocked = ph.isFromCamera && (ph.unlockTime.map { Date() < $0 } ?? false)
                return PinnedSlide(id: ph.id, image: ph.thumbnail, isLocked: isLocked, unlockTime: ph.unlockTime)
            }
        }
    }
}

struct PinnedSlide: Identifiable {
    let id: UUID
    let image: UIImage
    let isLocked: Bool
    let unlockTime: Date?
}

@MainActor
final class HomeViewModel: ObservableObject {

    @Published var pinnedFirstMet: UIImage? {
        didSet {
            DataPersistenceManager.shared.savePinnedFirstMet(pinnedFirstMet)
        }
    }
    @Published var pinnedOfficial: UIImage {
        didSet {
            DataPersistenceManager.shared.savePinnedOfficial(pinnedOfficial)
        }
    }
    @Published var moments: [Moment] {
        didSet {
            DataPersistenceManager.shared.saveMoments(moments)
            refreshDaySections()
            refreshOnThisDay()
            refreshMapDaySections()
            handleMomentCountChange()
        }
    }

    /// Cached "On This Day" sections. Recomputed only when moments change or the
    /// view appears — never inside `body`, so scrolling doesn't trigger Photos fetches.
    @Published private(set) var onThisDaySections: [DaySection] = []

    /// Cached geolocated day sections for the map — avoids re-grouping on every filter pass.
    @Published private(set) var mapDaySections: [DaySection] = []
    
    
    var allPinnedItems: [PinnedItem] {
        return pinnedItems
    }

    @Published var promptMemories: [PromptMemory] = [] {
        didSet {
            DataPersistenceManager.shared.savePromptMemories(promptMemories)
            refreshMapDaySections()
        }
    }
    
    let polaroidStore: LocalPolaroidStore
    private var releaseTimer: Timer?
    private var periodicCheckTimer: Timer?
    private var isInitializing = true
    private var cancellables = Set<AnyCancellable>()
    private let locationResolver = LocationNameResolver.shared
    private var isBackfillingCountries = false
    private var lastKnownMomentCount = DataPersistenceManager.shared.loadMoments().count

    private static let foundingPrompts: Set<String> = [
        "When we first met",
        "When we became official"
    ]

    /// Cached timeline day sections. Recomputed only when moments change — never inside
    /// `body`, so scrolling doesn't re-run the O(n log n) grouping/sorting over all moments.
    @Published private(set) var daySections: [DaySection] = []

    private func refreshDaySections() {
        let unpinnedMoments = moments.filter { !$0.isPinned && !Self.isFoundingMoment($0) }
        daySections = DaySection.grouped(from: unpinnedMoments)
    }

    var foundingMoments: [Moment] {
        let order = ["When we became official", "When we first met"]
        return order.compactMap { prompt in
            let matches = moments.filter { $0.promptText == prompt }
            return matches.first(where: { !$0.isPinned }) ?? matches.first
        }
    }

    var foundingDaySections: [DaySection] {
        let founding = foundingMoments
        // Group each founding moment into its own DaySection, preserving order
        return founding.map { moment in
            DaySection(date: moment.dateTaken, placeName: moment.placeName, moments: [moment])
        }
    }

    private static let foundingTimelineOrder = ["When we became official", "When we first met"]

    /// Every founding slot in timeline order — moment + section when present, nil when missing (shows placeholder).
    var foundingTimelineSlots: [(promptText: String, moment: Moment?, section: DaySection?)] {
        Self.foundingTimelineOrder.map { prompt in
            let matches = moments.filter { $0.promptText == prompt }
            guard let moment = matches.first(where: { !$0.isPinned }) ?? matches.first else {
                return (prompt, nil, nil)
            }
            let section = DaySection(date: moment.dateTaken, placeName: moment.placeName, moments: [moment])
            return (prompt, moment, section)
        }
    }

    private static func isFoundingMoment(_ moment: Moment) -> Bool {
        guard let prompt = moment.promptText else { return false }
        return foundingPrompts.contains(prompt)
    }

    /// Timeline cards use unpinned founding rows; repair data that only has a pinned copy.
    private func ensureFoundingTimelineMoments() {
        var updated = moments
        var changed = false

        for prompt in Self.foundingPrompts {
            let matches = updated.filter { $0.promptText == prompt }
            guard !matches.isEmpty else { continue }
            guard !matches.contains(where: { !$0.isPinned }) else { continue }
            guard let source = matches.first(where: \.isPinned) ?? matches.first else { continue }

            updated.append(
                Moment(
                    id: UUID(),
                    dateTaken: source.dateTaken,
                    assetIdentifier: source.assetIdentifier,
                    thumbnail: source.thumbnail,
                    placeName: source.placeName,
                    caption: source.caption,
                    voiceNotePath: source.voiceNotePath,
                    promptText: prompt,
                    isPinned: false,
                    pinnedAt: nil,
                    isLocked: source.isLocked,
                    unlockTime: source.unlockTime,
                    latitude: source.latitude,
                    longitude: source.longitude,
                    isAddedFromOnThisDay: source.isAddedFromOnThisDay,
                    isPlaceNameUserSet: source.isPlaceNameUserSet
                )
            )
            changed = true
        }

        if changed {
            moments = updated
        }
    }

    /// Recreates founding timeline rows from persisted pinned JPEGs when moments were deleted.
    private func ensureFoundingMomentsFromPinnedPhotos() {
        restoreFoundingMomentIfMissing(
            promptText: "When we became official",
            image: pinnedOfficial,
            pinnedAt: Date()
        )

        if let firstMetImage = pinnedFirstMet ?? DataPersistenceManager.shared.loadPinnedFirstMet() {
            restoreFoundingMomentIfMissing(
                promptText: "When we first met",
                image: firstMetImage,
                pinnedAt: Date().addingTimeInterval(-1)
            )
        }
    }

    private func restoreFoundingMomentIfMissing(
        promptText: String,
        image: UIImage,
        pinnedAt: Date
    ) {
        guard !moments.contains(where: { $0.promptText == promptText }) else { return }

        let dateTaken = resolvedFoundingPhotoDate(promptText: promptText)
        upsertFoundingMoment(
            promptText: promptText,
            image: image,
            dateTaken: dateTaken,
            assetIdentifier: nil,
            latitude: nil,
            longitude: nil,
            pinnedAt: pinnedAt
        )
    }

    private func resolvedFoundingPhotoDate(promptText: String) -> Date {
        if let saved = DataPersistenceManager.shared.loadFoundingPhotoDate(promptText: promptText) {
            return saved
        }
        if let fileDate = DataPersistenceManager.shared.pinnedPhotoFileModificationDate(promptText: promptText) {
            return fileDate
        }
        return Date()
    }

    func upsertFoundingMoment(
        promptText: String,
        image: UIImage,
        dateTaken: Date,
        assetIdentifier: String?,
        latitude: Double?,
        longitude: Double?,
        pinnedAt: Date
    ) {
        guard Self.foundingPrompts.contains(promptText) else { return }

        DataPersistenceManager.shared.saveFoundingPhotoDate(dateTaken, promptText: promptText)
        if promptText == "When we became official" {
            pinnedOfficial = image
        } else if promptText == "When we first met" {
            pinnedFirstMet = image
        }

        moments.removeAll { $0.promptText == promptText }

        let sharedFields = (
            dateTaken: dateTaken,
            assetIdentifier: assetIdentifier,
            thumbnail: image,
            promptText: promptText,
            latitude: latitude,
            longitude: longitude
        )

        let pinned = Moment(
            id: UUID(),
            dateTaken: sharedFields.dateTaken,
            assetIdentifier: sharedFields.assetIdentifier,
            thumbnail: sharedFields.thumbnail,
            promptText: sharedFields.promptText,
            isPinned: true,
            pinnedAt: pinnedAt,
            latitude: sharedFields.latitude,
            longitude: sharedFields.longitude
        )
        let unpinned = Moment(
            id: UUID(),
            dateTaken: sharedFields.dateTaken,
            assetIdentifier: sharedFields.assetIdentifier,
            thumbnail: sharedFields.thumbnail,
            promptText: sharedFields.promptText,
            isPinned: false,
            pinnedAt: nil,
            latitude: sharedFields.latitude,
            longitude: sharedFields.longitude
        )
        addMoments([pinned, unpinned])
    }
    
    var pinnedMoments: [Moment] {
        moments.filter { $0.isPinned }.sorted { ($0.pinnedAt ?? Date.distantPast) > ($1.pinnedAt ?? Date.distantPast) }
    }

    var pinnedItems: [PinnedItem] {
        var items: [PinnedItem] = []
        
        // Pinned Moments - founding entries stay single-photo cards.
        for moment in moments.filter({ $0.isPinned && Self.isFoundingMoment($0) }) {
            items.append(.moment(moment, [moment]))
        }

        // Pinned Moments - regular memories grouped by day/place into one card.
        let regularPinned = moments.filter { $0.isPinned && !Self.isFoundingMoment($0) }
        let groupedRegularPinned = Dictionary(grouping: regularPinned) { moment in
            "\(Calendar.current.startOfDay(for: moment.dateTaken).timeIntervalSince1970)|\(moment.placeName ?? "")"
        }
        for group in groupedRegularPinned.values {
            let sortedGroup = group.sorted { $0.dateTaken < $1.dateTaken }
            guard let representative = sortedGroup.first else { continue }
            items.append(.moment(representative, sortedGroup))
        }
        
        // Pinned Prompt Memories
        for prompt in promptMemories.filter({ $0.isPinned }) {
            items.append(.prompt(prompt))
        }
        
        return items.sorted { $0.pinnedAt > $1.pinnedAt }
    }

    var isEmpty: Bool {
        moments.isEmpty && promptMemories.isEmpty && polaroidStore.processingMemories.isEmpty
    }

    /// One timeline card represents every polaroid still waiting for the 9 PM release.
    var processingMemoryForTimeline: ProcessingMemory? {
        let pending = polaroidStore.processingMemories
        guard let newest = pending.max(by: { $0.date < $1.date }) else { return nil }
        guard let soonestUnlock = pending.map(\.unlockTime).min(), soonestUnlock != newest.unlockTime else {
            return newest
        }
        return ProcessingMemory(
            id: newest.id,
            date: newest.date,
            unlockTime: soonestUnlock,
            imageFileName: newest.imageFileName
        )
    }

    var processingMemoryCount: Int {
        polaroidStore.processingMemories.count
    }

    init(
        pinnedFirstMet: UIImage?,
        pinnedOfficial: UIImage,
        moments: [Moment] = [],
        polaroidStore: LocalPolaroidStore? = nil,
        loadFromPersistence: Bool = false
    ) {
        self.polaroidStore = polaroidStore ?? LocalPolaroidStore()
        
        if loadFromPersistence {
            self.pinnedFirstMet = DataPersistenceManager.shared.loadPinnedFirstMet()
            self.pinnedOfficial = DataPersistenceManager.shared.loadPinnedOfficial() ?? pinnedOfficial
            self.moments = DataPersistenceManager.shared.loadMoments()
            self.promptMemories = DataPersistenceManager.shared.loadPromptMemories()
        } else {
            self.pinnedFirstMet = pinnedFirstMet
            self.pinnedOfficial = pinnedOfficial
            self.moments = moments
        }
        
        isInitializing = false
        ensureFoundingTimelineMoments()
        ensureFoundingMomentsFromPinnedPhotos()
        refreshDaySections()
        refreshOnThisDay()
        refreshMapDaySections()

        setupPolaroidStoreObserver()
    }
    
    deinit {
        releaseTimer?.invalidate()
        periodicCheckTimer?.invalidate()
        cancellables.removeAll()
    }
    
    private func setupPolaroidStoreObserver() {
        polaroidStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func checkAndReleasePhotos() {
        let readyToRelease = polaroidStore.getUnreleasedEntriesReadyForRelease()
        if !readyToRelease.isEmpty {
            releasePolaroids(readyToRelease)
        }
        checkAndUnlockMoments()
        scheduleNextReleaseCheck()
        setupPeriodicUnlockCheck()
    }
    
    private func checkAndUnlockMoments() {
        let now = Date()
        var updated = false
        
        for index in moments.indices {
            if moments[index].isLocked, let unlockTime = moments[index].unlockTime, now >= unlockTime {
                moments[index].isLocked = false
                moments[index].unlockTime = nil
                updated = true
            }
        }
        
        for memoryIndex in promptMemories.indices {
            var memoryUpdated = false
            for photoIndex in promptMemories[memoryIndex].photos.indices {
                if let unlockTime = promptMemories[memoryIndex].photos[photoIndex].unlockTime,
                   now >= unlockTime {
                    promptMemories[memoryIndex].photos[photoIndex].unlockTime = nil
                    memoryUpdated = true
                }
            }
            if memoryUpdated {
                updated = true
            }
        }
        
        checkAndUnlockProcessingMemories()
        
        if updated {
            objectWillChange.send()
        }
    }
    
    private func checkAndUnlockProcessingMemories() {
        let now = Date()
        let unlockedMemories = polaroidStore.processingMemories.filter { $0.unlockTime <= now }
        
        if !unlockedMemories.isEmpty {
            var entriesToRelease: [PolaroidEntry] = []
            
            for memory in unlockedMemories {
                if let entry = polaroidStore.entries.first(where: { $0.id == memory.id }) {
                    entriesToRelease.append(entry)
                    polaroidStore.removeProcessingMemory(memory.id)
                }
            }
            
            // Mark entries as released (automatically at 9:00 PM)
            if !entriesToRelease.isEmpty {
                polaroidStore.releaseEntries(entriesToRelease)
                releasePolaroids(entriesToRelease)
            }
            
            // Force UI refresh
            objectWillChange.send()
        }
    }
    
    private func setupPeriodicUnlockCheck() {
        periodicCheckTimer?.invalidate()
        
        // Only set up periodic checks if there are processing memories
        guard !polaroidStore.processingMemories.isEmpty else { return }
        
        // Check every minute for unlocks to ensure smooth UI transition
        periodicCheckTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.checkAndUnlockMoments()
                
                // Stop periodic checks if no more processing memories
                if self.polaroidStore.processingMemories.isEmpty {
                    self.periodicCheckTimer?.invalidate()
                    self.periodicCheckTimer = nil
                }
            }
        }
    }

    func addMoments(_ newMoments: [Moment]) {
        var combined = moments + newMoments
        
        var seen = Set<UUID>()
        combined = combined.filter { moment in
            if seen.contains(moment.id) {
                return false
            }
            seen.insert(moment.id)
            return true
        }
        
        combined.sort { $0.dateTaken > $1.dateTaken }
        moments = combined
    }
    
    func savePinnedPhotos() {
        DataPersistenceManager.shared.savePinnedFirstMet(pinnedFirstMet)
        DataPersistenceManager.shared.savePinnedOfficial(pinnedOfficial)
    }
    
    func updatePinnedFirstMet(_ image: UIImage) {
        pinnedFirstMet = image
    }
    
    func updatePinnedOfficial(_ image: UIImage) {
        pinnedOfficial = image
    }
    
    func updateCaption(for momentId: UUID, caption: String, voiceNotePath: String? = nil) {
        if let index = moments.firstIndex(where: { $0.id == momentId }) {
            var newMoments = moments
            var updatedMoment = newMoments[index]
            updatedMoment.caption = caption.isEmpty ? nil : caption
            if let voicePath = voiceNotePath {
                updatedMoment.voiceNotePath = voicePath
            }
            newMoments[index] = updatedMoment
            moments = newMoments
        }
    }
    
    func updateMemory(
        section: DaySection,
        primaryMomentId: UUID,
        caption: String,
        placeName: String?,
        latitude: Double?,
        longitude: Double?,
        isPlaceNameUserSet: Bool = false,
        voiceNotePath: String? = nil
    ) {
        let momentIds = Set(section.moments.map(\.id))
        var newMoments = moments
        for index in newMoments.indices {
            guard momentIds.contains(newMoments[index].id) else { continue }
            if newMoments[index].id == primaryMomentId {
                newMoments[index].caption = caption.isEmpty ? nil : caption
                if let voicePath = voiceNotePath {
                    newMoments[index].voiceNotePath = voicePath
                }
            }
            newMoments[index].placeName = placeName
            newMoments[index].latitude = latitude
            newMoments[index].longitude = longitude
            newMoments[index].isPlaceNameUserSet = isPlaceNameUserSet
        }
        moments = newMoments
    }
    
    func addPromptMemory(_ memory: PromptMemory) {
        promptMemories.append(memory)
        promptMemories.sort { $0.date > $1.date }
    }

    func removePromptMemory(_ memory: PromptMemory) {
        promptMemories.removeAll { $0.id == memory.id }
    }

    func updatePromptMemoryLoveNote(for memoryId: UUID, loveNote: String) {
        if let index = promptMemories.firstIndex(where: { $0.id == memoryId }) {
            promptMemories[index].loveNote = loveNote
        }
    }

    func updatePromptMemory(
        memoryId: UUID,
        primaryPhotoId _: UUID,
        loveNote: String,
        placeName: String?,
        latitude: Double?,
        longitude: Double?,
        isPlaceNameUserSet: Bool = false
    ) {
        guard let index = promptMemories.firstIndex(where: { $0.id == memoryId }) else { return }
        promptMemories[index].loveNote = loveNote
        promptMemories[index].placeName = placeName
        promptMemories[index].latitude = latitude
        promptMemories[index].longitude = longitude
        promptMemories[index].isPlaceNameUserSet = isPlaceNameUserSet
    }

    func addPhotosToPromptMemory(memoryId: UUID, images: [UIImage]) {
        guard let index = promptMemories.firstIndex(where: { $0.id == memoryId }) else { return }
        let memory = promptMemories[index]
        let newPhotos = images.map { image in
            PromptPhoto(
                dateTaken: memory.date,
                thumbnail: image,
                latitude: memory.latitude,
                longitude: memory.longitude
            )
        }
        promptMemories[index].photos.append(contentsOf: newPhotos)
    }

    func removePhotoFromPromptMemory(memoryId: UUID, photoId: UUID) {
        guard let index = promptMemories.firstIndex(where: { $0.id == memoryId }) else { return }
        guard promptMemories[index].photos.count > 1 else { return }
        promptMemories[index].photos.removeAll { $0.id == photoId }
    }

    func syncPromptMemoryPhotos(
        memoryId: UUID,
        selectedAssetIds: Set<String>,
        selectedOrphanMomentIds: Set<UUID>
    ) async {
        guard let index = promptMemories.firstIndex(where: { $0.id == memoryId }) else { return }
        let memory = promptMemories[index]
        let existingAssetIds = Set(memory.photos.compactMap(\.assetIdentifier))

        var photos = memory.photos.filter { photo in
            if let assetId = photo.assetIdentifier {
                return selectedAssetIds.contains(assetId)
            }
            return selectedOrphanMomentIds.contains(photo.id)
        }

        let assetIdsToAdd = selectedAssetIds.subtracting(existingAssetIds)
        if !assetIdsToAdd.isEmpty {
            var assets: [PHAsset] = []
            for id in assetIdsToAdd {
                let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                if let asset = fetched.firstObject {
                    assets.append(asset)
                }
            }

            let created = await MomentFactory().createMoments(from: assets)
            for moment in created {
                photos.append(
                    PromptPhoto(
                        dateTaken: moment.dateTaken,
                        thumbnail: moment.thumbnail,
                        assetIdentifier: moment.assetIdentifier,
                        latitude: moment.latitude ?? memory.latitude,
                        longitude: moment.longitude ?? memory.longitude
                    )
                )
            }
        }

        photos.sort { $0.dateTaken < $1.dateTaken }
        promptMemories[index].photos = photos
    }
    
    func togglePromptMemoryPin(_ memory: PromptMemory) {
        if let index = promptMemories.firstIndex(where: { $0.id == memory.id }) {
            promptMemories[index].isPinned.toggle()
            promptMemories[index].pinnedAt = promptMemories[index].isPinned ? Date() : nil
        }
    }
    
    func updatePromptMemoryPhotos(_ originalPhotos: [PromptPhoto], with updatedPhotos: [PromptPhoto]) {
        // Find the prompt memory that contains these photos
        for index in promptMemories.indices {
            let memoryPhotoIds = Set(promptMemories[index].photos.map { $0.id })
            let originalPhotoIds = Set(originalPhotos.map { $0.id })
            
            // Check if this memory contains the original photos
            if !memoryPhotoIds.isDisjoint(with: originalPhotoIds) {
                promptMemories[index].photos = updatedPhotos
                break
            }
        }
    }
    
    func deletePromptPhoto(_ photo: PromptPhoto, from originalPhotos: [PromptPhoto]) {
        // Find the prompt memory that contains this photo
        for index in promptMemories.indices {
            if let photoIndex = promptMemories[index].photos.firstIndex(where: { $0.id == photo.id }) {
                promptMemories[index].photos.remove(at: photoIndex)
                
                // If no photos left in the memory, remove the entire memory
                if promptMemories[index].photos.isEmpty {
                    promptMemories.remove(at: index)
                }
                break
            }
        }
    }

    func removeMoments(from section: DaySection) {
        let momentIdsToRemove = Set(section.moments.map { $0.id })
        moments.removeAll { momentIdsToRemove.contains($0.id) }
    }
    
    func addPhotosToMemory(section: DaySection, images: [UIImage]) {
        guard let firstMoment = section.moments.first else { return }
        
        let newMoments = images.map { image in
            Moment(
                id: UUID(),
                dateTaken: firstMoment.dateTaken,
                assetIdentifier: nil,
                thumbnail: image,
                placeName: firstMoment.placeName,
                caption: firstMoment.caption,
                voiceNotePath: firstMoment.voiceNotePath,
                promptText: firstMoment.promptText,
                isPinned: false,
                pinnedAt: nil,
                isLocked: false,
                unlockTime: nil
            )
        }
        
        addMoments(newMoments)
    }

    func syncMemoryPhotos(
        section: DaySection,
        selectedAssetIds: Set<String>,
        selectedOrphanMomentIds: Set<UUID>
    ) async {
        guard let firstMoment = section.moments.first else { return }

        let existingAssetIds = Set(section.moments.compactMap(\.assetIdentifier))

        for moment in section.moments {
            if let assetId = moment.assetIdentifier {
                if !selectedAssetIds.contains(assetId) {
                    moments.removeAll { $0.id == moment.id }
                }
            } else if !selectedOrphanMomentIds.contains(moment.id) {
                moments.removeAll { $0.id == moment.id }
            }
        }

        let assetIdsToAdd = selectedAssetIds.subtracting(existingAssetIds)
        guard !assetIdsToAdd.isEmpty else { return }

        var assets: [PHAsset] = []
        for id in assetIdsToAdd {
            let fetched = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            if let asset = fetched.firstObject {
                assets.append(asset)
            }
        }

        let created = await MomentFactory().createMoments(from: assets)
        let enriched = created.map { moment -> Moment in
            var copy = moment
            copy.placeName = firstMoment.placeName
            copy.caption = firstMoment.caption
            copy.voiceNotePath = firstMoment.voiceNotePath
            copy.promptText = firstMoment.promptText
            copy.isPlaceNameUserSet = firstMoment.isPlaceNameUserSet
            if copy.latitude == nil { copy.latitude = firstMoment.latitude }
            if copy.longitude == nil { copy.longitude = firstMoment.longitude }
            return copy
        }
        addMoments(enriched)
    }
    
    func removePhotoFromMemory(section: DaySection, momentId: UUID) {
        guard section.moments.count > 1 else { return }
        moments.removeAll { $0.id == momentId }
    }
    
    func togglePin(for section: DaySection) {
        guard !section.moments.isEmpty else { return }
        let sectionMomentIds = Set(section.moments.map(\.id))
        let shouldPin = !section.moments.contains(where: \.isPinned)
        let pinTimestamp = Date()

        var newMoments = moments
        for index in newMoments.indices where sectionMomentIds.contains(newMoments[index].id) {
            newMoments[index].isPinned = shouldPin
            newMoments[index].pinnedAt = shouldPin ? pinTimestamp : nil
        }
        moments = newMoments
    }
    
    func unpinMoment(_ moment: Moment) {
        guard let index = moments.firstIndex(where: { $0.id == moment.id }) else { return }
        
        var newMoments = moments
        let hasUnpinnedSibling = newMoments.enumerated().contains { pair in
            let (otherIndex, other) = pair
            guard otherIndex != index else { return false }
            guard !other.isPinned else { return false }
            guard Calendar.current.isDate(other.dateTaken, inSameDayAs: moment.dateTaken) else { return false }
            return other.assetIdentifier == moment.assetIdentifier && (other.placeName ?? "") == (moment.placeName ?? "")
        }
        if hasUnpinnedSibling {
            // Legacy data may contain a pinned duplicate copy. Remove it instead of
            // turning it into a second unpinned row.
            newMoments.remove(at: index)
        } else {
            newMoments[index].isPinned = false
            newMoments[index].pinnedAt = nil
        }
        moments = newMoments
    }

    func deleteMoment(_ moment: Moment) {
        moments.removeAll { $0.id == moment.id }
    }
    
    func releasePolaroids(_ entries: [PolaroidEntry]) {
        var newMoments: [Moment] = []
        
        let laTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        var laCalendar = Calendar.current
        laCalendar.timeZone = laTimeZone
        
        for entry in entries {
            if let image = polaroidStore.loadImage(for: entry) {
                var isLocked = false
                var unlockTime: Date? = nil
                
                if let manualReleaseTime = entry.manuallyReleasedAt {
                    let captureDay = laCalendar.startOfDay(for: entry.capturedAt)
                    var releaseComponents = laCalendar.dateComponents([.year, .month, .day], from: captureDay)
                    releaseComponents.hour = 21
                    releaseComponents.minute = 0
                    releaseComponents.second = 0
                    
                    if let scheduledUnlockTime = laCalendar.date(from: releaseComponents) {
                        if manualReleaseTime < scheduledUnlockTime {
                            isLocked = true
                            unlockTime = scheduledUnlockTime
                        }
                    }
                }
                
                let moment = Moment(
                    id: entry.id,
                    dateTaken: entry.capturedAt,
                    assetIdentifier: nil,
                    thumbnail: image,
                    placeName: entry.placeName,
                    isLocked: isLocked,
                    unlockTime: unlockTime,
                    latitude: entry.latitude,
                    longitude: entry.longitude
                )
                newMoments.append(moment)
            }
        }
        
        addMoments(newMoments)
    }
    
    private func scheduleNextReleaseCheck() {
        releaseTimer?.invalidate()
        
        let laTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        var laCalendar = Calendar.current
        laCalendar.timeZone = laTimeZone
        
        let now = Date()
        let todayLA = laCalendar.startOfDay(for: now)
        
        var releaseComponents = laCalendar.dateComponents([.year, .month, .day], from: todayLA)
        releaseComponents.hour = 21
        releaseComponents.minute = 0
        releaseComponents.second = 0
        
        guard let todayReleaseTime = laCalendar.date(from: releaseComponents) else { return }
        
        let nextCheckTime: Date
        if now < todayReleaseTime {
            nextCheckTime = todayReleaseTime
        } else {
            guard let tomorrowLA = laCalendar.date(byAdding: .day, value: 1, to: todayLA) else { return }
            var tomorrowComponents = laCalendar.dateComponents([.year, .month, .day], from: tomorrowLA)
            tomorrowComponents.hour = 21
            tomorrowComponents.minute = 0
            tomorrowComponents.second = 0
            guard let tomorrowReleaseTime = laCalendar.date(from: tomorrowComponents) else { return }
            nextCheckTime = tomorrowReleaseTime
        }
        
        let timeInterval = nextCheckTime.timeIntervalSince(now)
        
        releaseTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAndReleasePhotos()
            }
        }
    }
    
    // MARK: - On This Day
    
    /// Recompute the cached `onThisDaySections`. Call on appear and whenever moments change.
    /// Cheap to call: it does a date filter first and only touches the Photos library once.
    func refreshOnThisDay(for date: Date = Date()) {
        onThisDaySections = computeOnThisDayMatches(for: date)
    }

    private func computeOnThisDayMatches(for date: Date = Date()) -> [DaySection] {
        // Use LA timezone consistently with the rest of the app
        guard let laTimeZone = TimeZone(identifier: "America/Los_Angeles") else {
            return []
        }

        var calendar = Calendar.current
        calendar.timeZone = laTimeZone

        let targetMonth = calendar.component(.month, from: date)
        let targetDay = calendar.component(.day, from: date)
        let currentYear = calendar.component(.year, from: date)

        // 1) Cheap date filter first — no Photos calls. This is almost always a tiny set.
        let dateMatches = moments.filter { moment in
            let momentMonth = calendar.component(.month, from: moment.dateTaken)
            let momentDay = calendar.component(.day, from: moment.dateTaken)
            let momentYear = calendar.component(.year, from: moment.dateTaken)
            return momentMonth == targetMonth && momentDay == targetDay && momentYear != currentYear
        }

        guard !dateMatches.isEmpty else { return [] }

        // 2) One batched Photos fetch to find screenshots among the few candidates,
        //    instead of a synchronous fetch per moment.
        let candidateIds = dateMatches.compactMap { $0.assetIdentifier }
        var screenshotIds = Set<String>()
        if !candidateIds.isEmpty {
            let fetch = PHAsset.fetchAssets(withLocalIdentifiers: candidateIds, options: nil)
            fetch.enumerateObjects { asset, _, _ in
                if asset.mediaSubtypes.contains(.photoScreenshot) {
                    screenshotIds.insert(asset.localIdentifier)
                }
            }
        }

        let matchingMoments = dateMatches.filter { moment in
            guard let id = moment.assetIdentifier else { return true }
            return !screenshotIds.contains(id)
        }

        // Group by year (all moments from the same year together)
        let groupedByYear = Dictionary(grouping: matchingMoments) { moment in
            calendar.component(.year, from: moment.dateTaken)
        }

        // Create a DaySection for each year, sorted by year descending (most recent first)
        return groupedByYear.map { year, yearMoments in
            let sortedMoments = yearMoments.sorted { $0.dateTaken < $1.dateTaken }
            // Use the first moment's date and place for the section
            let firstMoment = sortedMoments.first!
            return DaySection(
                date: firstMoment.dateTaken,
                placeName: firstMoment.placeName,
                moments: sortedMoments
            )
        }
        .sorted { $0.date > $1.date }
    }
    
    func flattenedPhotos(for section: DaySection) -> [Moment] {
        return section.moments.sorted { $0.dateTaken < $1.dateTaken }
    }

    /// All photos in the same memory cluster as `momentId` (timeline card or founding slot).
    func flattenedPhotosForMemory(containingMomentId momentId: UUID) -> [Moment] {
        if let section = daySections.first(where: { $0.moments.contains(where: { $0.id == momentId }) }) {
            return flattenedPhotos(for: section)
        }
        if let section = foundingDaySections.first(where: { $0.moments.contains(where: { $0.id == momentId }) }) {
            return flattenedPhotos(for: section)
        }
        if let memory = promptMemories.first(where: { $0.photos.contains(where: { $0.id == momentId }) }) {
            return memory.sortedViewerMoments
        }
        if let moment = moments.first(where: { $0.id == momentId }) {
            return [moment]
        }
        return []
    }

    func promptMemory(containingPhotoId photoId: UUID) -> PromptMemory? {
        promptMemories.first(where: { $0.photos.contains(where: { $0.id == photoId }) })
    }
    
    /// Check if a moment has already been added to the timeline from On This Day
    func isAddedFromOnThisDay(_ moment: Moment) -> Bool {
        moments.contains { existing in
            existing.isAddedFromOnThisDay &&
            (existing.assetIdentifier == moment.assetIdentifier ||
             existing.thumbnail.pngData() == moment.thumbnail.pngData())
        }
    }
    
    // MARK: - Map Helpers
    
    func memoriesWithLocation() -> [DaySection] {
        mapDaySections
    }

    private func refreshMapDaySections() {
        let momentsWithCoordinates = moments.filter { $0.location != nil }
        let promptMomentsWithCoordinates = promptMemories
            .filter { $0.latitude != nil && $0.longitude != nil }
            .map { convertToMapMoment($0) }

        mapDaySections = DaySection.grouped(from: momentsWithCoordinates + promptMomentsWithCoordinates)
    }
    
    var availableCountries: [String] {
        let names = moments.compactMap { moment -> String? in
            guard let country = moment.country?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !country.isEmpty else { return nil }
            return country
        }
        return Set(names).sorted()
    }

    func availableYears() -> [Int] {
        let momentYears = Set(moments.map { $0.year })
        let promptYears = Set(promptMemories.map { Calendar.current.component(.year, from: $0.date) })
        return momentYears.union(promptYears).sorted(by: >)
    }
    
    /// Fill `country` for legacy moments that have coordinates but no country yet.
    /// Throttled to respect CLGeocoder limits; batches one save at the end.
    func backfillCountriesIfNeeded() {
        guard !isBackfillingCountries else { return }

        let targets = moments.filter { $0.country == nil && $0.location != nil }
        guard !targets.isEmpty else { return }

        isBackfillingCountries = true
        Task { @MainActor in
            defer { isBackfillingCountries = false }

            // Flush resolved countries into `moments` periodically so progress
            // survives if the task is interrupted (next launch only re-geocodes
            // the moments that weren't flushed yet — i.e. it's resumable).
            var pending: [UUID: String] = [:]
            @MainActor func flush() {
                guard !pending.isEmpty else { return }
                var newMoments = moments
                for index in newMoments.indices {
                    if let country = pending[newMoments[index].id] {
                        newMoments[index].country = country
                    }
                }
                moments = newMoments
                pending.removeAll()
            }

            for moment in targets {
                guard let coordinate = moment.location?.coordinate else { continue }
                if let country = await locationResolver.country(from: coordinate) {
                    pending[moment.id] = country
                    if pending.count >= 20 { flush() }
                }
                // ~50 requests/minute ceiling for CLGeocoder.
                try? await Task.sleep(nanoseconds: 1_200_000_000)
            }

            flush()
        }
    }

    func memories(forYear year: Int) -> [DaySection] {
        // Filter for memories with location data for the specified year
        let filteredMoments = moments.filter { $0.year == year && $0.location != nil }
        let filteredPromptMoments = promptMemories
            .filter { 
                Calendar.current.component(.year, from: $0.date) == year && 
                $0.latitude != nil && 
                $0.longitude != nil 
            }
            .map { convertToMapMoment($0) }
            
        return DaySection.grouped(from: filteredMoments + filteredPromptMoments)
    }
    
    private func convertToMapMoment(_ memory: PromptMemory) -> Moment {
        return Moment(
            id: memory.id,
            dateTaken: memory.date,
            assetIdentifier: memory.photos.first?.assetIdentifier,
            thumbnail: memory.photos.first?.thumbnail ?? UIImage(),
            placeName: memory.placeName,
            caption: memory.loveNote,
            promptText: memory.promptText,
            isPinned: memory.isPinned,
            pinnedAt: memory.pinnedAt,
            latitude: memory.latitude,
            longitude: memory.longitude
        )
    }

    // MARK: - Table of Contents Logic

    /// One row per timeline place/day (moments) plus one row per prompt memory.
    var tocSections: [DaySection] {
        let momentSections = DaySection.grouped(
            from: moments.filter { !$0.isPinned && !Self.isFoundingMoment($0) }
        )
        let promptSections = promptMemories
            .filter { !$0.isPinned }
            .map { $0.asEditingDaySection() }
        return (momentSections + promptSections)
            .sorted { $0.timelineSortDate > $1.timelineSortDate }
    }

    var tocPinnedPromptMemories: [PromptMemory] {
        promptMemories
            .filter(\.isPinned)
            .sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
    }

    func promptMemory(for section: DaySection) -> PromptMemory? {
        let photoIds = Set(section.moments.map(\.id))
        guard !photoIds.isEmpty else { return nil }
        return promptMemories.first { memory in
            memory.photos.contains { photoIds.contains($0.id) }
        }
    }

    func tocRowTitle(for section: DaySection) -> String {
        if let memory = promptMemory(for: section) {
            let place = memory.placeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !place.isEmpty { return place }
            return memory.promptText
        }
        return section.placeDisplay
    }

    func tocLoveNote(for section: DaySection) -> String? {
        if let memory = promptMemory(for: section) {
            let note = memory.loveNote.trimmingCharacters(in: .whitespacesAndNewlines)
            return note.isEmpty ? nil : note
        }
        let caption = section.moments
            .compactMap { $0.caption?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return caption
    }

    var tocGroups: [YearGroup] {
        let groupedByYear = Dictionary(grouping: tocSections) { section in
            Calendar.current.component(.year, from: section.date)
        }

        return groupedByYear.map { year, yearSections in
            let seasons = Dictionary(grouping: yearSections) { section in
                Season.from(date: section.date)
            }

            let seasonGroups = seasons.map { season, seasonSections in
                SeasonGroup(season: season, sections: seasonSections.sorted { $0.timelineSortDate > $1.timelineSortDate })
            }
            .sorted { lhs, rhs in
                let lhsNewest = lhs.sections.map(\.timelineSortDate).max() ?? .distantPast
                let rhsNewest = rhs.sections.map(\.timelineSortDate).max() ?? .distantPast
                return lhsNewest > rhsNewest
            }

            return YearGroup(id: year, seasons: seasonGroups)
        }
        .sorted { $0.id > $1.id }
    }

    var tocMilestones: [Moment] {
        // Get the "official" ones and the "first met" ones from moments, plus pinned ones if they are founding
        // The requirements say: Special Milestones Section (Pinned at Top)
        // When We First Met, When We Became Official, The Beginning
        
        var milestones: [Moment] = []
        
        // Find "When We First Met"
        if let firstMet = moments.first(where: { $0.promptText == "When we first met" }) {
            milestones.append(firstMet)
        }
        
        // Find "When We Became Official"
        if let official = moments.first(where: { $0.promptText == "When we became official" }) {
            milestones.append(official)
        }
        
        return milestones
    }

    /// Matches the memory rows shown in the table of contents (milestones + year/season sections).
    var tocMemoryCount: Int {
        tocMilestones.count + tocPinnedPromptMemories.count + tocSections.count
    }

    // MARK: - Moment Milestone Banners

    private func handleMomentCountChange() {
        let newCount = moments.count
        defer {
            lastKnownMomentCount = newCount
            NotificationManager.shared.refresh()
        }
        guard newCount > lastKnownMomentCount else { return }
        let dp = DataPersistenceManager.shared
        var celebrated = dp.loadCelebratedMomentMilestones()
        let crossed = NotificationPlanner().crossedMilestones(
            oldCount: lastKnownMomentCount, newCount: newCount, alreadyCelebrated: celebrated)
        guard let top = crossed.max() else { return }
        celebrated.formUnion(crossed)         // record all crossed; fire only the top
        dp.saveCelebratedMomentMilestones(celebrated)
        NotificationManager.shared.fireMilestone(top)
    }
}

// MARK: - Preview Helpers

extension HomeViewModel {

    static var filledPreview: HomeViewModel {
        HomeViewModel(
            pinnedFirstMet: Moment.samplePinnedFirstMet,
            pinnedOfficial: Moment.samplePinnedOfficial,
            moments: Moment.sampleMoments
        )
    }

    static var emptyPreview: HomeViewModel {
        HomeViewModel(
            pinnedFirstMet: nil,
            pinnedOfficial: Moment.samplePinnedOfficial
        )
    }
}
