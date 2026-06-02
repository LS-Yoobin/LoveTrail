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

    private var userLettersFileURL: URL {
        documentsDirectory.appendingPathComponent("user_letters.json")
    }

    private var petStateFileURL: URL {
        documentsDirectory.appendingPathComponent("pet_state.json")
    }
    
    private let userDefaults = UserDefaults.standard
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    private let lastActiveScreenKey = "lastActiveScreen"
    private let userNicknameKey = "userNickname"
    private let readInAppNotificationIDsKey = "readInAppNotificationIDs"
    private let isPartnerUnlockedKey = "isPartnerUnlocked"
    private let partnerInviteCodeKey = "partnerInviteCode"
    private let appJoinedDateKey = "appJoinedDate"
    private let foundingOfficialDateKey = "foundingOfficialPhotoDate"
    private let foundingFirstMetDateKey = "foundingFirstMetPhotoDate"
    
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

    func saveFoundingPhotoDate(_ date: Date, promptText: String) {
        let key = promptText == "When we became official"
            ? foundingOfficialDateKey
            : foundingFirstMetDateKey
        userDefaults.set(date.timeIntervalSince1970, forKey: key)
    }

    func loadFoundingPhotoDate(promptText: String) -> Date? {
        let key = promptText == "When we became official"
            ? foundingOfficialDateKey
            : foundingFirstMetDateKey
        let interval = userDefaults.double(forKey: key)
        guard interval > 0 else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    func pinnedPhotoFileModificationDate(promptText: String) -> Date? {
        let url = promptText == "When we became official" ? officialPhotoURL : firstMetPhotoURL
        guard fileManager.fileExists(atPath: url.path),
              let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date else {
            return nil
        }
        return modified
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

    func saveUserLetters(_ letters: [UserLetter]) {
        guard let data = try? encoder.encode(letters) else { return }
        try? data.write(to: userLettersFileURL)
    }

    func loadUserLetters() -> [UserLetter] {
        guard fileManager.fileExists(atPath: userLettersFileURL.path),
              let data = try? Data(contentsOf: userLettersFileURL),
              let letters = try? decoder.decode([UserLetter].self, from: data) else {
            return []
        }
        return letters
    }

    func appendUserLetter(_ letter: UserLetter) {
        var letters = loadUserLetters()
        letters.append(letter)
        saveUserLetters(letters)
    }
    
    // MARK: - Pet (Adopt a Pet)

    func savePetState(_ state: PetState) {
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: petStateFileURL)
    }

    func loadPetState() -> PetState {
        guard fileManager.fileExists(atPath: petStateFileURL.path),
              let data = try? Data(contentsOf: petStateFileURL),
              let state = try? decoder.decode(PetState.self, from: data) else {
            return PetState()
        }
        return state
    }

    func setOnboardingCompleted(_ completed: Bool) {
        userDefaults.set(completed, forKey: hasCompletedOnboardingKey)
    }
    
    func hasCompletedOnboarding() -> Bool {
        return userDefaults.bool(forKey: hasCompletedOnboardingKey)
    }

    /// The day the user first opened Baby Town — used as each kitty's "birth date"
    /// on the Visit Pet profile. Backfills from an existing adoption date when upgrading.
    func loadOrCreateAppJoinedDate() -> Date {
        if let stored = userDefaults.object(forKey: appJoinedDateKey) as? Date {
            return stored
        }
        let fallback = loadPetState().adoptedDate ?? Date()
        userDefaults.set(fallback, forKey: appJoinedDateKey)
        return fallback
    }

    /// Whether the paid "Invite Partner to Town" tier has been unlocked.
    /// NOTE: currently set by a stubbed purchase; replace with a real StoreKit
    /// entitlement check when billing is wired up.
    func setPartnerUnlocked(_ unlocked: Bool) {
        userDefaults.set(unlocked, forKey: isPartnerUnlockedKey)
    }

    func isPartnerUnlocked() -> Bool {
        return userDefaults.bool(forKey: isPartnerUnlockedKey)
    }

    /// Returns the persisted partner invite code, generating + saving one on
    /// first use so it stays stable across launches.
    func loadOrCreatePartnerInviteCode() -> String {
        if let existing = userDefaults.string(forKey: partnerInviteCodeKey), !existing.isEmpty {
            return existing
        }
        let code = PartnerInvite.generateCode()
        userDefaults.set(code, forKey: partnerInviteCodeKey)
        return code
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

    func readInAppNotificationIDs() -> Set<String> {
        guard let ids = userDefaults.stringArray(forKey: readInAppNotificationIDsKey) else {
            return []
        }
        return Set(ids)
    }

    func markInAppNotificationRead(id: String) {
        var ids = readInAppNotificationIDs()
        ids.insert(id)
        userDefaults.set(Array(ids), forKey: readInAppNotificationIDsKey)
    }

    func clearAllData() {
        try? fileManager.removeItem(at: momentsFileURL)
        try? fileManager.removeItem(at: firstMetPhotoURL)
        try? fileManager.removeItem(at: officialPhotoURL)
        try? fileManager.removeItem(at: promptMemoriesFileURL)
        try? fileManager.removeItem(at: userLettersFileURL)
        try? fileManager.removeItem(at: petStateFileURL)
        userDefaults.removeObject(forKey: hasCompletedOnboardingKey)
        userDefaults.removeObject(forKey: lastActiveScreenKey)
        userDefaults.removeObject(forKey: userNicknameKey)
        userDefaults.removeObject(forKey: readInAppNotificationIDsKey)
        userDefaults.removeObject(forKey: isPartnerUnlockedKey)
        userDefaults.removeObject(forKey: partnerInviteCodeKey)
        userDefaults.removeObject(forKey: appJoinedDateKey)
        userDefaults.removeObject(forKey: foundingOfficialDateKey)
        userDefaults.removeObject(forKey: foundingFirstMetDateKey)
    }
}
