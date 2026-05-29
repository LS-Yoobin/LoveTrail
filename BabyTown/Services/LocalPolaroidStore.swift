import Foundation
import UIKit
import Combine
import CoreLocation

@MainActor
final class LocalPolaroidStore: ObservableObject {
    
    @Published private(set) var entries: [PolaroidEntry] = []
    @Published private(set) var processingMemories: [ProcessingMemory] = []
    
    private let fileManager = FileManager.default
    private let entriesFileName = "polaroid_entries.json"
    private let imagesDirectoryName = "polaroid_images"
    private let vibesDirectoryName = "polaroid_vibes"
    private let videosDirectoryName = "polaroid_videos"
    private let processingMemoriesFileName = "processing_memories.json"
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var entriesFileURL: URL {
        documentsDirectory.appendingPathComponent(entriesFileName)
    }
    
    private var imagesDirectory: URL {
        documentsDirectory.appendingPathComponent(imagesDirectoryName)
    }

    private var vibesDirectory: URL {
        documentsDirectory.appendingPathComponent(vibesDirectoryName)
    }

    private var videosDirectory: URL {
        documentsDirectory.appendingPathComponent(videosDirectoryName)
    }

    init() {
        createMediaDirectoriesIfNeeded()
        loadEntries()
        loadProcessingMemories()
    }
    
    private func createMediaDirectoriesIfNeeded() {
        for directory in [imagesDirectory, vibesDirectory, videosDirectory] {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }
    
    private func loadEntries() {
        guard fileManager.fileExists(atPath: entriesFileURL.path),
              let data = try? Data(contentsOf: entriesFileURL),
              let decoded = try? JSONDecoder().decode([PolaroidEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }
    
    private var processingMemoriesFileURL: URL {
        documentsDirectory.appendingPathComponent(processingMemoriesFileName)
    }
    
    private func loadProcessingMemories() {
        guard fileManager.fileExists(atPath: processingMemoriesFileURL.path),
              let data = try? Data(contentsOf: processingMemoriesFileURL),
              let decoded = try? JSONDecoder().decode([ProcessingMemory].self, from: data) else {
            processingMemories = []
            return
        }
        processingMemories = decoded
    }
    
    private func saveProcessingMemories() {
        guard let data = try? JSONEncoder().encode(processingMemories) else { return }
        try? data.write(to: processingMemoriesFileURL)
    }
    
    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: entriesFileURL)
    }
    
    func savePhoto(
        _ image: UIImage,
        placeName: String? = nil,
        location: CLLocation? = nil,
        vibeSourceURL: URL? = nil,
        videoSourceURL: URL? = nil
    ) -> PolaroidEntry? {
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)

        guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return nil }

        do {
            try jpegData.write(to: fileURL)

            var vibeFileName: String?
            if let vibeSourceURL {
                let name = "\(id.uuidString).m4a"
                let dest = vibesDirectory.appendingPathComponent(name)
                try? fileManager.removeItem(at: dest)
                try fileManager.copyItem(at: vibeSourceURL, to: dest)
                vibeFileName = name
            }

            var videoFileName: String?
            if let videoSourceURL {
                let name = "\(id.uuidString).mov"
                let dest = videosDirectory.appendingPathComponent(name)
                try? fileManager.removeItem(at: dest)
                try fileManager.copyItem(at: videoSourceURL, to: dest)
                videoFileName = name
            }

            let entry = PolaroidEntry(
                id: id,
                capturedAt: Date(),
                imageFileName: fileName,
                released: false,
                manuallyReleasedAt: nil,
                placeName: placeName,
                location: location,
                vibeFileName: vibeFileName,
                videoFileName: videoFileName
            )
            entries.append(entry)
            saveEntries()

            createProcessingMemory(for: entry)

            return entry
        } catch {
            return nil
        }
    }
    
    private func isPhotoTakenAfter9PM(_ date: Date) -> Bool {
        let laTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        var laCalendar = Calendar.current
        laCalendar.timeZone = laTimeZone
        
        let hour = laCalendar.component(.hour, from: date)
        return hour >= 21 // 9 PM or later
    }
    
    private func createProcessingMemory(for entry: PolaroidEntry) {
        let laTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        var laCalendar = Calendar.current
        laCalendar.timeZone = laTimeZone
        
        let captureDay = laCalendar.startOfDay(for: entry.capturedAt)
        var releaseComponents = laCalendar.dateComponents([.year, .month, .day], from: captureDay)
        releaseComponents.hour = 21
        releaseComponents.minute = 0
        releaseComponents.second = 0
        
        guard var unlockTime = laCalendar.date(from: releaseComponents) else { return }
        
        // If photo was taken after 9 PM, unlock at 9 PM the next day
        if entry.capturedAt > unlockTime {
            guard let nextDayUnlock = laCalendar.date(byAdding: .day, value: 1, to: unlockTime) else { return }
            unlockTime = nextDayUnlock
        }
        
        let processingMemory = ProcessingMemory(
            id: entry.id,
            date: entry.capturedAt,
            unlockTime: unlockTime,
            imageFileName: entry.imageFileName
        )
        
        processingMemories.append(processingMemory)
        saveProcessingMemories()
    }
    
    func loadImage(for entry: PolaroidEntry) -> UIImage? {
        let fileURL = imagesDirectory.appendingPathComponent(entry.imageFileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    
    func todaysCaptureCount() -> Int {
        let laTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        var laCalendar = Calendar.current
        laCalendar.timeZone = laTimeZone

        let now = Date()
        let currentPeriodStart = get9PMBoundaryDate(for: now)

        return entries.filter { entry in
            let entryPeriodStart = get9PMBoundaryDate(for: entry.capturedAt)
            return laCalendar.isDate(entryPeriodStart, inSameDayAs: currentPeriodStart)
        }.count
    }
    
    private func get9PMBoundaryDate(for date: Date) -> Date {
        let laTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        var laCalendar = Calendar.current
        laCalendar.timeZone = laTimeZone
        
        let dayStart = laCalendar.startOfDay(for: date)
        var components = DateComponents()
        components.hour = 21 // 9 PM
        components.minute = 0
        components.second = 0
        
        guard let ninePM = laCalendar.date(byAdding: components, to: dayStart) else {
            return dayStart
        }
        
        // If the date is before 9 PM, the boundary should be 9 PM of the previous day
        if date < ninePM {
            return laCalendar.date(byAdding: .day, value: -1, to: ninePM) ?? ninePM
        }
        
        return ninePM
    }

    func canCapturePhoto() -> Bool {
        return true
    }

    func todaysUnreleasedEntries() -> [PolaroidEntry] {
        let laTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        var laCalendar = Calendar.current
        laCalendar.timeZone = laTimeZone

        let now = Date()
        let currentPeriodStart = get9PMBoundaryDate(for: now)

        return entries.filter { entry in
            let entryPeriodStart = get9PMBoundaryDate(for: entry.capturedAt)
            return laCalendar.isDate(entryPeriodStart, inSameDayAs: currentPeriodStart) && !entry.released
        }
    }
    
    func releaseEntries(_ entriesToRelease: [PolaroidEntry]) {
        let idsToRelease = Set(entriesToRelease.map { $0.id })
        for index in entries.indices {
            if idsToRelease.contains(entries[index].id) {
                entries[index].released = true
            }
        }
        saveEntries()
    }
    
    func releaseEntriesManually(_ entriesToRelease: [PolaroidEntry]) {
        let idsToRelease = Set(entriesToRelease.map { $0.id })
        let now = Date()
        for index in entries.indices {
            if idsToRelease.contains(entries[index].id) {
                entries[index].released = true
                entries[index].manuallyReleasedAt = now
            }
        }
        saveEntries()
    }
    
    func getUnreleasedEntriesReadyForRelease() -> [PolaroidEntry] {
        let laTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        var laCalendar = Calendar.current
        laCalendar.timeZone = laTimeZone
        
        let now = Date()
        
        return entries.filter { entry in
            guard !entry.released else { return false }
            
            let captureDay = laCalendar.startOfDay(for: entry.capturedAt)
            
            var releaseComponents = laCalendar.dateComponents([.year, .month, .day], from: captureDay)
            releaseComponents.hour = 21
            releaseComponents.minute = 0
            releaseComponents.second = 0
            
            guard var releaseTime = laCalendar.date(from: releaseComponents) else { return false }
            
            // If photo was taken after 9 PM, release at 9 PM the next day
            if entry.capturedAt > releaseTime {
                guard let nextDayRelease = laCalendar.date(byAdding: .day, value: 1, to: releaseTime) else { return false }
                releaseTime = nextDayRelease
            }
            
            return now >= releaseTime
        }
    }
    
    func removeProcessingMemory(_ memoryId: UUID) {
        processingMemories.removeAll { $0.id == memoryId }
        saveProcessingMemories()
    }
    
    func reset() {
        entries = []
        saveEntries()
        processingMemories = []
        saveProcessingMemories()
        
        try? fileManager.removeItem(at: imagesDirectory)
        try? fileManager.removeItem(at: vibesDirectory)
        try? fileManager.removeItem(at: videosDirectory)
        createMediaDirectoriesIfNeeded()
    }
}
