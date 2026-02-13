import Foundation
import Combine
import SwiftUI
import UIKit

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
        }
    }
    @Published var promptMemories: [PromptMemory] = [] {
        didSet {
            DataPersistenceManager.shared.savePromptMemories(promptMemories)
        }
    }
    
    let polaroidStore: LocalPolaroidStore
    private var releaseTimer: Timer?
    private var isInitializing = true

    var daySections: [DaySection] {
        let unpinnedMoments = moments.filter { !$0.isPinned }
        return DaySection.grouped(from: unpinnedMoments)
    }
    
    var pinnedMoments: [Moment] {
        moments.filter { $0.isPinned }.sorted { ($0.pinnedAt ?? Date.distantPast) > ($1.pinnedAt ?? Date.distantPast) }
    }

    var isEmpty: Bool {
        moments.isEmpty
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
    }
    
    deinit {
        releaseTimer?.invalidate()
    }
    
    func checkAndReleasePhotos() {
        let readyToRelease = polaroidStore.getUnreleasedEntriesReadyForRelease()
        if !readyToRelease.isEmpty {
            releasePolaroids(readyToRelease)
        }
        checkAndUnlockMoments()
        scheduleNextReleaseCheck()
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
        
        for memory in unlockedMemories {
            if let entry = polaroidStore.entries.first(where: { $0.id == memory.id }) {
                releasePolaroids([entry])
                polaroidStore.removeProcessingMemory(memory.id)
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
    
    func addPromptMemory(_ memory: PromptMemory) {
        promptMemories.append(memory)
        promptMemories.sort { $0.date > $1.date }
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
    
    func removePhotoFromMemory(section: DaySection, momentId: UUID) {
        guard section.moments.count > 1 else { return }
        moments.removeAll { $0.id == momentId }
    }
    
    func togglePin(for section: DaySection) {
        guard let firstMoment = section.moments.first else { return }
        
        if firstMoment.isPinned {
            moments.removeAll { $0.id == firstMoment.id }
        } else {
            let pinnedCopy = Moment(
                id: UUID(),
                dateTaken: firstMoment.dateTaken,
                assetIdentifier: firstMoment.assetIdentifier,
                thumbnail: firstMoment.thumbnail,
                placeName: firstMoment.placeName,
                caption: firstMoment.caption,
                voiceNotePath: firstMoment.voiceNotePath,
                promptText: firstMoment.promptText,
                isPinned: true,
                pinnedAt: Date(),
                isLocked: firstMoment.isLocked,
                unlockTime: firstMoment.unlockTime
            )
            moments.append(pinnedCopy)
        }
    }
    
    func unpinMoment(_ moment: Moment) {
        guard let index = moments.firstIndex(where: { $0.id == moment.id }) else { return }
        
        var newMoments = moments
        var updatedMoment = newMoments[index]
        updatedMoment.isPinned = false
        updatedMoment.pinnedAt = nil
        newMoments[index] = updatedMoment
        moments = newMoments
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
                    placeName: nil,
                    isLocked: isLocked,
                    unlockTime: unlockTime
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
