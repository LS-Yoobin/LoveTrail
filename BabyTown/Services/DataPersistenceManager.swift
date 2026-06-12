import Foundation
import UIKit
import GardenCore

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

    private var gardenStateFileURL: URL {
        documentsDirectory.appendingPathComponent("garden_state.json")
    }

    private var coupleProfileFileURL: URL {
        documentsDirectory.appendingPathComponent("couple_profile.json")
    }

    private var memoryCanvasesFileURL: URL {
        documentsDirectory.appendingPathComponent("memory_canvases.json")
    }

    private var preludeCapturesFileURL: URL {
        documentsDirectory.appendingPathComponent("prelude_captures.json")
    }

    private var preludeChapterFileURL: URL {
        documentsDirectory.appendingPathComponent("prelude_chapter.json")
    }

    private var preludeVoiceMemosDirectory: URL {
        documentsDirectory.appendingPathComponent("PreludeVoiceMemos")
    }

    private func preludeVoiceMemoURL(fileId: String) -> URL {
        preludeVoiceMemosDirectory.appendingPathComponent(fileId)
    }

    private var userAvatarURL: URL {
        pinnedPhotosDirectory.appendingPathComponent("couple_user_avatar.jpg")
    }

    private func specialDatePhotoURL(id: UUID) -> URL {
        pinnedPhotosDirectory.appendingPathComponent("special_date_\(id.uuidString).jpg")
    }

    private func stickerImageURL(id: UUID) -> URL {
        pinnedPhotosDirectory.appendingPathComponent("profile_sticker_\(id.uuidString).png")
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
    private let celebratedMomentMilestonesKey = "celebratedMomentMilestones"
    private let petNeedsNotifiedWhileLowKey = "petNeedsNotifiedWhileLow"
    private let petMissesYouNotifiedForInteractionAtKey = "petMissesYouNotifiedForInteractionAt"
    private let colorThemeKey = "colorTheme"

    private init() {
        createDirectoriesIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        if !fileManager.fileExists(atPath: pinnedPhotosDirectory.path) {
            try? fileManager.createDirectory(at: pinnedPhotosDirectory, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: preludeVoiceMemosDirectory.path) {
            try? fileManager.createDirectory(at: preludeVoiceMemosDirectory, withIntermediateDirectories: true)
        }
    }
    
    func saveMoments(_ moments: [Moment]) {
        guard let data = try? encoder.encode(moments) else { return }
        try? data.write(to: momentsFileURL)
        // Persist any thumbnails not yet on disk (new moments + lazy migration of legacy data).
        for moment in moments {
            ThumbnailStore.shared.persistIfNeeded(for: moment.id)
        }
    }

    func loadCelebratedMomentMilestones() -> Set<Int> {
        let arr = userDefaults.array(forKey: celebratedMomentMilestonesKey) as? [Int] ?? []
        return Set(arr)
    }

    func saveCelebratedMomentMilestones(_ set: Set<Int>) {
        userDefaults.set(Array(set), forKey: celebratedMomentMilestonesKey)
    }

    func isPetNeedsNotifiedWhileLow() -> Bool {
        userDefaults.bool(forKey: petNeedsNotifiedWhileLowKey)
    }

    func setPetNeedsNotifiedWhileLow(_ notified: Bool) {
        userDefaults.set(notified, forKey: petNeedsNotifiedWhileLowKey)
    }

    func petMissesYouNotifiedForInteractionAt() -> Date? {
        userDefaults.object(forKey: petMissesYouNotifiedForInteractionAtKey) as? Date
    }

    func setPetMissesYouNotifiedForInteractionAt(_ date: Date?) {
        if let date {
            userDefaults.set(date, forKey: petMissesYouNotifiedForInteractionAtKey)
        } else {
            userDefaults.removeObject(forKey: petMissesYouNotifiedForInteractionAtKey)
        }
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
        for photo in memories.flatMap(\.photos) {
            ThumbnailStore.shared.persistIfNeeded(for: photo.id)
        }
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

    func saveGardenState(_ state: GardenState) {
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: gardenStateFileURL)
    }

    /// Tolerant load — returns a fresh, blooming garden when nothing is stored.
    func loadGardenState() -> GardenState {
        guard fileManager.fileExists(atPath: gardenStateFileURL.path),
              let data = try? Data(contentsOf: gardenStateFileURL),
              let state = try? decoder.decode(GardenState.self, from: data) else {
            return GardenState()
        }
        return state
    }

    func saveCoupleProfile(_ profile: CoupleProfile) {
        guard let data = try? encoder.encode(profile) else { return }
        try? data.write(to: coupleProfileFileURL)
        NotificationManager.shared.refresh()
    }

    /// Saves the onboarding birthday into Important Dates and sets the profile display name.
    func saveOnboardingUserBirthday(_ date: Date, nickname: String) {
        var profile = loadCoupleProfile()
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            profile.displayName = trimmed
        }
        let birthday = SpecialDate.localUserBirthday(
            title: SpecialDate.birthdayTitle(for: trimmed),
            date: date
        )
        profile.specialDates.removeAll { $0.id == SpecialDate.localUserBirthdayID }
        profile.specialDates.append(birthday)
        saveCoupleProfile(profile)
    }

    /// Saves the partner's birthday into Important Dates (stable id for timeline ordering).
    func savePartnerBirthday(_ date: Date, partnerName: String) {
        var profile = loadCoupleProfile()
        let birthday = SpecialDate.localPartnerBirthday(
            title: SpecialDate.partnerBirthdayTitle(for: partnerName),
            date: date
        )
        profile.specialDates.removeAll { $0.id == SpecialDate.localPartnerBirthdayID }
        profile.specialDates.append(birthday)
        saveCoupleProfile(profile)
    }

    /// Tolerant load — returns an empty profile when nothing is stored.
    func loadCoupleProfile() -> CoupleProfile {
        guard fileManager.fileExists(atPath: coupleProfileFileURL.path),
              let data = try? Data(contentsOf: coupleProfileFileURL),
              var profile = try? decoder.decode(CoupleProfile.self, from: data) else {
            return CoupleProfile()
        }
        if SpecialDate.migrateBirthdayEntries(in: &profile) {
            saveCoupleProfile(profile)
        }
        return profile
    }

    func saveUserAvatar(_ image: UIImage?) {
        guard let image, let jpeg = image.jpegData(compressionQuality: 0.85) else {
            try? fileManager.removeItem(at: userAvatarURL)
            return
        }
        try? jpeg.write(to: userAvatarURL)
    }

    func loadUserAvatar() -> UIImage? {
        guard fileManager.fileExists(atPath: userAvatarURL.path),
              let data = try? Data(contentsOf: userAvatarURL) else { return nil }
        return UIImage(data: data)
    }

    func saveSpecialDatePhoto(_ image: UIImage?, id: UUID) {
        let url = specialDatePhotoURL(id: id)
        guard let image, let jpeg = image.jpegData(compressionQuality: 0.85) else {
            try? fileManager.removeItem(at: url)
            return
        }
        try? jpeg.write(to: url)
    }

    func loadSpecialDatePhoto(id: UUID) -> UIImage? {
        let url = specialDatePhotoURL(id: id)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteSpecialDatePhoto(id: UUID) {
        try? fileManager.removeItem(at: specialDatePhotoURL(id: id))
    }

    func saveStickerImage(_ image: UIImage, id: UUID) {
        let url = stickerImageURL(id: id)
        guard let png = image.pngData() else { return }
        try? png.write(to: url)
    }

    func loadStickerImage(id: UUID) -> UIImage? {
        let url = stickerImageURL(id: id)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteStickerImage(id: UUID) {
        try? fileManager.removeItem(at: stickerImageURL(id: id))
    }

    func loadMemoryCanvases() -> [String: MemoryCanvas] {
        guard fileManager.fileExists(atPath: memoryCanvasesFileURL.path),
              let data = try? Data(contentsOf: memoryCanvasesFileURL),
              let canvases = try? decoder.decode([MemoryCanvas].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: canvases.map { ($0.memoryKey, $0) })
    }

    func saveMemoryCanvas(_ canvas: MemoryCanvas) {
        var all = loadMemoryCanvases()
        all[canvas.memoryKey] = canvas
        let list = Array(all.values)
        guard let data = try? encoder.encode(list) else { return }
        try? data.write(to: memoryCanvasesFileURL)
    }

    // MARK: - Prelude

    func savePreludeCaptures(_ captures: [PreludeCapture]) {
        guard let data = try? encoder.encode(captures) else { return }
        try? data.write(to: preludeCapturesFileURL)
    }

    func loadPreludeCaptures() -> [PreludeCapture] {
        guard fileManager.fileExists(atPath: preludeCapturesFileURL.path),
              let data = try? Data(contentsOf: preludeCapturesFileURL),
              let captures = try? decoder.decode([PreludeCapture].self, from: data) else {
            return []
        }
        return captures
    }

    func savePreludeChapter(_ chapter: PreludeChapter) {
        guard let data = try? encoder.encode(chapter) else { return }
        try? data.write(to: preludeChapterFileURL)
    }

    func loadPreludeChapter() -> PreludeChapter? {
        guard fileManager.fileExists(atPath: preludeChapterFileURL.path),
              let data = try? Data(contentsOf: preludeChapterFileURL),
              let chapter = try? decoder.decode(PreludeChapter.self, from: data) else {
            return nil
        }
        return chapter
    }

    func savePreludeVoiceMemo(data: Data, fileId: String) {
        let url = preludeVoiceMemoURL(fileId: fileId)
        try? data.write(to: url)
    }

    func loadPreludeVoiceMemoData(fileId: String) -> Data? {
        let url = preludeVoiceMemoURL(fileId: fileId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    func deletePreludeVoiceMemo(fileId: String) {
        try? fileManager.removeItem(at: preludeVoiceMemoURL(fileId: fileId))
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

    // MARK: - Color Theme

    func saveColorTheme(_ theme: ColorTheme) {
        userDefaults.set(theme.rawValue, forKey: colorThemeKey)
    }

    /// Returns the persisted theme, defaulting to `.pink` when unset or invalid.
    func loadColorTheme() -> ColorTheme {
        guard let raw = userDefaults.string(forKey: colorThemeKey),
              let theme = ColorTheme(rawValue: raw) else {
            return .pink
        }
        return theme
    }

    func clearAllData() {
        try? fileManager.removeItem(at: momentsFileURL)
        try? fileManager.removeItem(at: firstMetPhotoURL)
        try? fileManager.removeItem(at: officialPhotoURL)
        try? fileManager.removeItem(at: promptMemoriesFileURL)
        try? fileManager.removeItem(at: userLettersFileURL)
        try? fileManager.removeItem(at: petStateFileURL)
        try? fileManager.removeItem(at: gardenStateFileURL)
        try? fileManager.removeItem(at: coupleProfileFileURL)
        try? fileManager.removeItem(at: memoryCanvasesFileURL)
        try? fileManager.removeItem(at: userAvatarURL)
        try? fileManager.removeItem(at: preludeCapturesFileURL)
        try? fileManager.removeItem(at: preludeChapterFileURL)
        try? fileManager.removeItem(at: preludeVoiceMemosDirectory)
        userDefaults.removeObject(forKey: hasCompletedOnboardingKey)
        userDefaults.removeObject(forKey: lastActiveScreenKey)
        userDefaults.removeObject(forKey: userNicknameKey)
        userDefaults.removeObject(forKey: readInAppNotificationIDsKey)
        userDefaults.removeObject(forKey: isPartnerUnlockedKey)
        userDefaults.removeObject(forKey: partnerInviteCodeKey)
        userDefaults.removeObject(forKey: appJoinedDateKey)
        userDefaults.removeObject(forKey: foundingOfficialDateKey)
        userDefaults.removeObject(forKey: foundingFirstMetDateKey)
        userDefaults.removeObject(forKey: colorThemeKey)
        BackgroundMusicImporter.clearImportedSong()
        MomentVideoStore.shared.removeAll()
    }
}
