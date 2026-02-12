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
        DaySection.grouped(from: moments)
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
        scheduleNextReleaseCheck()
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
            var updatedMoment = moments[index]
            updatedMoment.caption = caption.isEmpty ? nil : caption
            if let voicePath = voiceNotePath {
                updatedMoment.voiceNotePath = voicePath
            }
            moments[index] = updatedMoment
        }
    }
    
    func addPromptMemory(_ memory: PromptMemory) {
        promptMemories.append(memory)
        promptMemories.sort { $0.date > $1.date }
    }
    
    func releasePolaroids(_ entries: [PolaroidEntry]) {
        var newMoments: [Moment] = []
        
        for entry in entries {
            if let image = polaroidStore.loadImage(for: entry) {
                let moment = Moment(
                    id: entry.id,
                    dateTaken: entry.capturedAt,
                    assetIdentifier: nil,
                    thumbnail: image,
                    placeName: nil
                )
                newMoments.append(moment)
            }
        }
        
        polaroidStore.releaseEntries(entries)
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
