import Foundation
import UIKit

@MainActor
final class DataPersistenceManager {
    
    static let shared = DataPersistenceManager()
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var momentsFileURL: URL {
        documentsDirectory.appendingPathComponent("moments.json")
    }
    
    private var pinnedPhotosDirectory: URL {
        documentsDirectory.appendingPathComponent("pinned_photos")
    }
    
    private var firstMetPhotoURL: URL {
        pinnedPhotosDirectory.appendingPathComponent("first_met.jpg")
    }
    
    private var officialPhotoURL: URL {
        pinnedPhotosDirectory.appendingPathComponent("official.jpg")
    }
    
    private var promptMemoriesFileURL: URL {
        documentsDirectory.appendingPathComponent("prompt_memories.json")
    }
    
    private let userDefaults = UserDefaults.standard
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private let lastActiveScreenKey = "lastActiveScreen"
    private let userNicknameKey = "userNickname"
    
    private init() {
        createDirectoriesIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        if !fileManager.fileExists(atPath: pinnedPhotosDirectory.path) {
            try? fileManager.createDirectory(at: pinnedPhotosDirectory, withIntermediateDirectories: true)
        }
    }
    
    func saveMoments(_ moments: [Moment]) {
        guard let data = try? encoder.encode(moments) else { return }
        try? data.write(to: momentsFileURL)
    }
    
    func loadMoments() -> [Moment] {
        guard fileManager.fileExists(atPath: momentsFileURL.path),
              let data = try? Data(contentsOf: momentsFileURL),
              let moments = try? decoder.decode([Moment].self, from: data) else {
            return []
        }
        return moments
    }
    
    func savePinnedFirstMet(_ image: UIImage?) {
        guard let image = image,
              let jpegData = image.jpegData(compressionQuality: 0.85) else {
            try? fileManager.removeItem(at: firstMetPhotoURL)
            return
        }
        try? jpegData.write(to: firstMetPhotoURL)
    }
    
    func loadPinnedFirstMet() -> UIImage? {
        guard fileManager.fileExists(atPath: firstMetPhotoURL.path),
              let data = try? Data(contentsOf: firstMetPhotoURL) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    func savePinnedOfficial(_ image: UIImage) {
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else { return }
        try? jpegData.write(to: officialPhotoURL)
    }
    
    func loadPinnedOfficial() -> UIImage? {
        guard fileManager.fileExists(atPath: officialPhotoURL.path),
              let data = try? Data(contentsOf: officialPhotoURL) else {
            return nil
        }
        return UIImage(data: data)
    }
    
    func savePromptMemories(_ memories: [PromptMemory]) {
        guard let data = try? encoder.encode(memories) else { return }
        try? data.write(to: promptMemoriesFileURL)
    }
    
    func loadPromptMemories() -> [PromptMemory] {
        guard fileManager.fileExists(atPath: promptMemoriesFileURL.path),
              let data = try? Data(contentsOf: promptMemoriesFileURL),
              let memories = try? decoder.decode([PromptMemory].self, from: data) else {
            return []
        }
        return memories
    }
    
    func setOnboardingCompleted(_ completed: Bool) {
        userDefaults.set(completed, forKey: hasCompletedOnboardingKey)
    }
    
    func hasCompletedOnboarding() -> Bool {
        return userDefaults.bool(forKey: hasCompletedOnboardingKey)
    }
    
    func saveLastActiveScreen(_ screen: String) {
        userDefaults.set(screen, forKey: lastActiveScreenKey)
    }
    
    func loadLastActiveScreen() -> String? {
        return userDefaults.string(forKey: lastActiveScreenKey)
    }
    
    func saveUserNickname(_ nickname: String) {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        userDefaults.set(trimmed, forKey: userNicknameKey)
    }
    
    func loadUserNickname() -> String? {
        guard let nickname = userDefaults.string(forKey: userNicknameKey) else { return nil }
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    func clearAllData() {
        try? fileManager.removeItem(at: momentsFileURL)
        try? fileManager.removeItem(at: firstMetPhotoURL)
        try? fileManager.removeItem(at: officialPhotoURL)
        try? fileManager.removeItem(at: promptMemoriesFileURL)
        userDefaults.removeObject(forKey: hasCompletedOnboardingKey)
        userDefaults.removeObject(forKey: lastActiveScreenKey)
        userDefaults.removeObject(forKey: userNicknameKey)
    }
}
