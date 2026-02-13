import Foundation
import UIKit
import Combine

@MainActor
final class LocalPolaroidStore: ObservableObject {
    
    @Published private(set) var entries: [PolaroidEntry] = []
    @Published private(set) var processingMemories: [ProcessingMemory] = []
    
    private let fileManager = FileManager.default
    private let entriesFileName = "polaroid_entries.json"
    private let imagesDirectoryName = "polaroid_images"
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
    
    init() {
        createImagesDirectoryIfNeeded()
        loadEntries()
        loadProcessingMemories()
    }
    
    private func createImagesDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: imagesDirectory.path) {
            try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
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
    
    func savePhoto(_ image: UIImage) -> PolaroidEntry? {
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return nil }
        
        do {
            try jpegData.write(to: fileURL)
            
            let currentCount = todaysCaptureCount()
            let isFifth = (currentCount + 1) == 1
            
            let entry = PolaroidEntry(
                id: id,
                capturedAt: Date(),
                imageFileName: fileName,
                released: false,
                manuallyReleasedAt: nil,
                isFifthPhoto: isFifth
            )
            entries.append(entry)
            saveEntries()
            
            if isFifth {
                createProcessingMemory(for: entry)
            }
            
            return entry
        } catch {
            return nil
        }
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
        
        guard let unlockTime = laCalendar.date(from: releaseComponents) else { return }
        
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
        let currentDayStart = laCalendar.startOfDay(for: now)

        return entries.filter { entry in
            let entryDayStart = laCalendar.startOfDay(for: entry.capturedAt)
            return laCalendar.isDate(entryDayStart, inSameDayAs: currentDayStart)
        }.count
    }

    func canCapturePhoto() -> Bool {
        let laTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        var laCalendar = Calendar.current
        laCalendar.timeZone = laTimeZone

        let now = Date()
        let hour = laCalendar.component(.hour, from: now)
        let count = todaysCaptureCount()

        // If 5 photos taken and it's 9PM or later, block until midnight
        if count >= 5 && hour >= 21 {
            return false
        }
        // Otherwise allow if under limit
        return count < 5
    }

    func todaysUnreleasedEntries() -> [PolaroidEntry] {
        let laTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        var laCalendar = Calendar.current
        laCalendar.timeZone = laTimeZone

        let now = Date()
        let currentDayStart = laCalendar.startOfDay(for: now)

        return entries.filter { entry in
            let entryDayStart = laCalendar.startOfDay(for: entry.capturedAt)
            return laCalendar.isDate(entryDayStart, inSameDayAs: currentDayStart) && !entry.released
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
            
            guard let releaseTime = laCalendar.date(from: releaseComponents) else { return false }
            
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
        createImagesDirectoryIfNeeded()
    }
}
