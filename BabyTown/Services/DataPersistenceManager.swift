import Foundation
import UIKit
import GardenCore

@MainActor
final class DataPersistenceManager {
    
    static let shared = DataPersistenceManager()
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// The signed-out bucket, and the name used for the anonymous Prelude phase
    /// before a user has an account.
    private static let anonymousScopeId = "anonymous"

    /// Scopes for which we've already checked/run the one-time migration this launch.
    private var provisionedDocumentScopes: Set<String> = []
    private var provisionedDefaultsScopes: Set<String> = []

    /// Every top-level item DataPersistenceManager used to store directly under
    /// `Documents/` before storage became per-account. Used only to migrate
    /// pre-existing installs into the scoped layout, once.
    private static let legacyTopLevelItemNames = [
        "moments.json", "pinned_photos", "prompt_memories.json", "user_letters.json",
        "pet_state.json", "garden_state.json", "couple_profile.json", "memory_canvases.json",
        "prelude_captures.json", "prelude_chapter.json", "partner_gift_captures.json", "archive_bundle.json",
        "reconnect_invite.json", "PreludeVoiceMemos", "letter_voice_memos",
        "letter_stickers", "letter_photos", "PreludePhotos", "prelude_gift_song",
    ]

    /// Every UserDefaults.standard key DataPersistenceManager used before storage
    /// became per-account. Used only for the one-time migration.
    private var legacyDefaultsKeys: [String] {
        [
            hasCompletedOnboardingKey, lastActiveScreenKey, userNicknameKey,
            readInAppNotificationIDsKey, isPartnerUnlockedKey, partnerInviteCodeKey,
            appJoinedDateKey, foundingOfficialDateKey, foundingFirstMetDateKey,
            celebratedMomentMilestonesKey, petNeedsNotifiedWhileLowKey,
            petMissesYouNotifiedForInteractionAtKey, colorThemeKey, partnerEmailKey,
            userEmailKey, isPartnerAccountKey, inviterNameKey, pendingPartnerInviteKey,
            pendingInviteCodeKey, pendingInvitePartnerNameKey, hasUnreadMailKey,
        ]
    }

    /// The signed-in user's id, or the shared anonymous bucket pre-signup / signed-out.
    /// All local storage is scoped by this so multiple accounts on one device (or a
    /// signed-out Prelude phase followed by account creation) don't see each other's data.
    private var currentScopeId: String {
        AuthService.shared.currentUser?.id ?? Self.anonymousScopeId
    }

    private func defaultsSuiteName(for scopeId: String) -> String {
        "com.covela.userdata.\(scopeId)"
    }

    private var documentsDirectory: URL {
        let root = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let scopeId = currentScopeId
        let scoped = root
            .appendingPathComponent("CovelaUserData", isDirectory: true)
            .appendingPathComponent(scopeId, isDirectory: true)
        provisionDocumentsScopeIfNeeded(scoped, scopeId: scopeId, legacyRoot: root)
        return scoped
    }

    /// One-time-per-launch: migrates legacy flat `Documents/*` files (pre-scoping installs)
    /// into the current scope, or — for a freshly created account — adopts whatever was
    /// journaled anonymously before signup. No-ops once the scope already has data.
    private func provisionDocumentsScopeIfNeeded(_ scoped: URL, scopeId: String, legacyRoot: URL) {
        guard !provisionedDocumentScopes.contains(scopeId) else { return }
        provisionedDocumentScopes.insert(scopeId)

        if !fileManager.fileExists(atPath: scoped.path) {
            try? fileManager.createDirectory(at: scoped, withIntermediateDirectories: true)
        }

        // Media subdirectories for this scope must exist before any save/load call writes
        // into them — every scope needs this created freshly, not just whichever scope was
        // active when DataPersistenceManager.shared was first constructed.
        for subdirectoryName in ["pinned_photos", "PreludeVoiceMemos", "letter_voice_memos", "PreludePhotos", "prelude_gift_song"] {
            let subdirectory = scoped.appendingPathComponent(subdirectoryName)
            if !fileManager.fileExists(atPath: subdirectory.path) {
                try? fileManager.createDirectory(at: subdirectory, withIntermediateDirectories: true)
            }
        }

        let scopedIsEmpty = (try? fileManager.contentsOfDirectory(atPath: scoped.path).isEmpty) ?? true
        guard scopedIsEmpty else { return }

        var movedLegacyItem = false
        for name in Self.legacyTopLevelItemNames {
            let source = legacyRoot.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            if (try? fileManager.moveItem(at: source, to: scoped.appendingPathComponent(name))) != nil {
                movedLegacyItem = true
            }
        }
        if movedLegacyItem { return }

        guard scopeId != Self.anonymousScopeId else { return }
        let anonymousDir = legacyRoot
            .appendingPathComponent("CovelaUserData", isDirectory: true)
            .appendingPathComponent(Self.anonymousScopeId, isDirectory: true)
        guard let items = try? fileManager.contentsOfDirectory(atPath: anonymousDir.path), !items.isEmpty else { return }
        for name in items {
            try? fileManager.moveItem(at: anonymousDir.appendingPathComponent(name), to: scoped.appendingPathComponent(name))
        }
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

    private var partnerGiftCapturesFileURL: URL {
        documentsDirectory.appendingPathComponent("partner_gift_captures.json")
    }

    private var archiveBundleFileURL: URL {
        documentsDirectory.appendingPathComponent("archive_bundle.json")
    }

    private var reconnectInviteFileURL: URL {
        documentsDirectory.appendingPathComponent("reconnect_invite.json")
    }

    private var preludeVoiceMemosDirectory: URL {
        documentsDirectory.appendingPathComponent("PreludeVoiceMemos")
    }

    private var letterVoiceMemosDirectory: URL {
        documentsDirectory.appendingPathComponent("letter_voice_memos")
    }

    private var letterStickersDirectory: URL {
        documentsDirectory.appendingPathComponent("letter_stickers")
    }

    private var letterPhotosDirectory: URL {
        documentsDirectory.appendingPathComponent("letter_photos")
    }

    private var preludePhotosDirectory: URL {
        documentsDirectory.appendingPathComponent("PreludePhotos")
    }

    private var preludeGiftSongDirectory: URL {
        documentsDirectory.appendingPathComponent("prelude_gift_song")
    }

    private var preludeGiftSongMetadataURL: URL {
        preludeGiftSongDirectory.appendingPathComponent("metadata.json")
    }

    private func preludeVoiceMemoURL(fileId: String) -> URL {
        preludeVoiceMemosDirectory.appendingPathComponent(fileId)
    }

    private func letterVoiceMemoURL(fileId: String) -> URL {
        letterVoiceMemosDirectory.appendingPathComponent(fileId)
    }

    private func letterStickerImageURL(id: UUID) -> URL {
        letterStickersDirectory.appendingPathComponent("\(id.uuidString).png")
    }

    private func letterPhotoImageURL(id: UUID) -> URL {
        letterPhotosDirectory.appendingPathComponent("\(id.uuidString).jpg")
    }

    private func preludePhotoURL(photoId: UUID) -> URL {
        preludePhotosDirectory.appendingPathComponent("\(photoId.uuidString).jpg")
    }

    private var userAvatarURL: URL {
        pinnedPhotosDirectory.appendingPathComponent("couple_user_avatar.jpg")
    }

    private var partnerAvatarURL: URL {
        pinnedPhotosDirectory.appendingPathComponent("partner_avatar.jpg")
    }

    private func specialDatePhotoURL(id: UUID) -> URL {
        pinnedPhotosDirectory.appendingPathComponent("special_date_\(id.uuidString).jpg")
    }

    private func stickerImageURL(id: UUID) -> URL {
        pinnedPhotosDirectory.appendingPathComponent("profile_sticker_\(id.uuidString).png")
    }
    
    /// Scoped to the current account (or the anonymous bucket) via a dedicated suite,
    /// so switching accounts on one device doesn't see each other's defaults.
    private var userDefaults: UserDefaults {
        let scopeId = currentScopeId
        let suite = UserDefaults(suiteName: defaultsSuiteName(for: scopeId)) ?? .standard
        provisionDefaultsScopeIfNeeded(suite, scopeId: scopeId)
        return suite
    }

    /// One-time-per-launch: migrates legacy `UserDefaults.standard` values (pre-scoping
    /// installs) into the current scope's suite, or — for a freshly created account —
    /// adopts whatever was set anonymously before signup.
    private func provisionDefaultsScopeIfNeeded(_ suite: UserDefaults, scopeId: String) {
        guard !provisionedDefaultsScopes.contains(scopeId) else { return }
        provisionedDefaultsScopes.insert(scopeId)

        let keys = legacyDefaultsKeys
        guard !keys.contains(where: { suite.object(forKey: $0) != nil }) else { return }

        let standard = UserDefaults.standard
        if keys.contains(where: { standard.object(forKey: $0) != nil }) {
            for key in keys {
                guard let value = standard.object(forKey: key) else { continue }
                suite.set(value, forKey: key)
                standard.removeObject(forKey: key)
            }
            return
        }

        guard scopeId != Self.anonymousScopeId,
              let anonymousSuite = UserDefaults(suiteName: defaultsSuiteName(for: Self.anonymousScopeId)) else { return }
        for key in keys {
            guard let value = anonymousSuite.object(forKey: key) else { continue }
            suite.set(value, forKey: key)
            anonymousSuite.removeObject(forKey: key)
        }
    }

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
    private let partnerEmailKey = "partnerEmail"
    private let userEmailKey = "userEmail"
    private let isPartnerAccountKey = "isPartnerAccount"
    private let inviterNameKey = "inviterName"
    private let pendingPartnerInviteKey = "pendingPartnerInvite"
    private let pendingInviteCodeKey = "pendingInviteCode"
    private let pendingInvitePartnerNameKey = "pendingInvitePartnerName"
    private let hasUnreadMailKey = "hasUnreadMail"

    private init() {}

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

    func updateUserLetter(_ letter: UserLetter) {
        var letters = loadUserLetters()
        guard let index = letters.firstIndex(where: { $0.id == letter.id }) else { return }
        letters[index] = letter
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
        if profile.pruneExpiredGardenMood() {
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

    func savePartnerEmail(_ email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        userDefaults.set(trimmed, forKey: partnerEmailKey)
    }

    func loadPartnerEmail() -> String? {
        userDefaults.string(forKey: partnerEmailKey)
    }

    func saveUserEmail(_ email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        userDefaults.set(trimmed, forKey: userEmailKey)
    }

    func loadUserEmail() -> String? {
        userDefaults.string(forKey: userEmailKey)
    }

    /// Whether the local user joined via the partner invite flow (not the inviter).
    func setPartnerAccount(_ isPartner: Bool) {
        userDefaults.set(isPartner, forKey: isPartnerAccountKey)
    }

    func isPartnerAccount() -> Bool {
        if userDefaults.bool(forKey: isPartnerAccountKey) { return true }
        // Invited partners persist email under partnerEmail; inviters use userEmail.
        return loadPartnerEmail() != nil && loadUserEmail() == nil
    }

    func savePartnerProfilePhoto(_ image: UIImage) {
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        try? jpeg.write(to: partnerAvatarURL)
    }

    func loadPartnerProfilePhoto() -> UIImage? {
        guard fileManager.fileExists(atPath: partnerAvatarURL.path),
              let data = try? Data(contentsOf: partnerAvatarURL) else { return nil }
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

    func savePartnerGiftCaptures(_ captures: [PreludeCapture]) {
        guard let data = try? encoder.encode(captures) else { return }
        try? data.write(to: partnerGiftCapturesFileURL)
    }

    func loadPartnerGiftCaptures() -> [PreludeCapture] {
        guard fileManager.fileExists(atPath: partnerGiftCapturesFileURL.path),
              let data = try? Data(contentsOf: partnerGiftCapturesFileURL),
              let captures = try? decoder.decode([PreludeCapture].self, from: data) else {
            return []
        }
        return captures
    }

    /// True when the couple has any prelude gift content worth surfacing in official mode.
    func hasAccessiblePreludeContent() -> Bool {
        if loadPreludeGiftSong() != nil { return true }
        return !loadAccessiblePreludeGiftCaptures().isEmpty
    }

    /// Merges `photo_path` from the server into local prelude captures (by `serverId`).
    func mergeServerPhotoPaths(from serverCaptures: [PreludeAPIClient.ServerCaptureSummary]) {
        guard !serverCaptures.isEmpty else { return }
        var local = loadPreludeCaptures()
        var changed = false

        for server in serverCaptures {
            guard let photoPath = server.photo_path,
                  let normalized = CovelaMediaPath.normalizePermanentPath(photoPath) else { continue }
            guard let index = local.firstIndex(where: { $0.serverId == server.id }) else { continue }
            if local[index].remotePhotoPath != normalized {
                local[index].remotePhotoPath = normalized
                changed = true
            }
        }

        if changed {
            savePreludeCaptures(local)
        }
    }

    /// Gift captures to show in the prelude book: partner gift, chapter snapshot, or own gift.
    func loadAccessiblePreludeGiftCaptures() -> [PreludeCapture] {
        var combined: [PreludeCapture] = []
        var seenIds = Set<UUID>()

        func appendUnique(_ captures: [PreludeCapture]) {
            for capture in captures where seenIds.insert(capture.id).inserted {
                combined.append(capture)
            }
        }

        appendUnique(loadPartnerGiftCaptures())

        if let chapter = loadPreludeChapter() {
            let giftIds = Set(chapter.giftCaptureIds)
            let chapterCaptures = loadPreludeCaptures()
                .filter { giftIds.contains($0.id) || $0.isPartnerRetroactive }
            appendUnique(chapterCaptures)
        }

        let ownGift = loadPreludeCaptures()
            .filter { $0.isIncludedInGift && !$0.isPartnerRetroactive }
        appendUnique(ownGift)

        return combined.sorted {
            if $0.timelineDate != $1.timelineDate { return $0.timelineDate < $1.timelineDate }
            return $0.createdAt < $1.createdAt
        }
    }

    /// Snapshots the prelude gift into a chapter the first time a couple goes official.
    func recordPreludeChapterIfNeeded() {
        guard loadPreludeChapter() == nil else { return }
        let captures = loadAccessiblePreludeGiftCaptures()
        guard !captures.isEmpty else { return }
        let chapter = PreludeChapter(
            startDate: captures.map(\.timelineDate).min() ?? Date(),
            officialDate: Date(),
            creatorUserId: "local",
            partnerUserId: "partner",
            giftCaptureIds: captures.map(\.id)
        )
        savePreludeChapter(chapter)
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

    func preludeVoiceMemoFileURL(fileId: String) -> URL {
        preludeVoiceMemoURL(fileId: fileId)
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

    func saveLetterVoiceMemo(data: Data, fileId: String) {
        let url = letterVoiceMemoURL(fileId: fileId)
        try? data.write(to: url)
    }

    func loadLetterVoiceMemoData(fileId: String) -> Data? {
        let url = letterVoiceMemoURL(fileId: fileId)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    func deleteLetterVoiceMemo(fileId: String) {
        try? fileManager.removeItem(at: letterVoiceMemoURL(fileId: fileId))
    }

    func saveLetterStickerImage(_ image: UIImage, id: UUID) {
        try? fileManager.createDirectory(at: letterStickersDirectory, withIntermediateDirectories: true)
        let url = letterStickerImageURL(id: id)
        guard let png = image.pngData() else { return }
        try? png.write(to: url)
    }

    func loadLetterStickerImage(id: UUID) -> UIImage? {
        let url = letterStickerImageURL(id: id)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteLetterStickerImage(id: UUID) {
        try? fileManager.removeItem(at: letterStickerImageURL(id: id))
    }

    func saveLetterPhotoImage(_ image: UIImage, id: UUID) {
        try? fileManager.createDirectory(at: letterPhotosDirectory, withIntermediateDirectories: true)
        let url = letterPhotoImageURL(id: id)
        guard let jpeg = image.jpegData(compressionQuality: 0.88) else { return }
        try? jpeg.write(to: url)
    }

    func loadLetterPhotoImage(id: UUID) -> UIImage? {
        let url = letterPhotoImageURL(id: id)
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func deleteLetterPhotoImage(id: UUID) {
        try? fileManager.removeItem(at: letterPhotoImageURL(id: id))
    }

    func savePreludePhoto(_ image: UIImage, photoId: UUID) {
        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            print("[DataPersistenceManager] savePreludePhoto FAILED — jpegData() returned nil for photoId=\(photoId)")
            return
        }
        let url = preludePhotoURL(photoId: photoId)
        do {
            try jpegData.write(to: url)
            print("[DataPersistenceManager] savePreludePhoto OK — photoId=\(photoId) bytes=\(jpegData.count) path=\(url.path)")
        } catch {
            print("[DataPersistenceManager] savePreludePhoto FAILED — photoId=\(photoId) path=\(url.path) error=\(error)")
        }
    }

    func loadPreludePhoto(photoId: UUID) -> UIImage? {
        let url = preludePhotoURL(photoId: photoId)
        guard fileManager.fileExists(atPath: url.path) else {
            print("[DataPersistenceManager] loadPreludePhoto MISS — no file at \(url.path) for photoId=\(photoId)")
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            print("[DataPersistenceManager] loadPreludePhoto FAILED — file exists but unreadable at \(url.path) for photoId=\(photoId)")
            return nil
        }
        if UIImage(data: data) == nil {
            print("[DataPersistenceManager] loadPreludePhoto FAILED — file exists but not decodable as UIImage, photoId=\(photoId) bytes=\(data.count)")
        }
        return UIImage(data: data)
    }

    func deletePreludePhoto(photoId: UUID) {
        try? fileManager.removeItem(at: preludePhotoURL(photoId: photoId))
    }

    // MARK: - Prelude Gift Song

    func savePreludeGiftSong(_ song: PreludeGiftSong, audioData: Data) {
        try? fileManager.createDirectory(at: preludeGiftSongDirectory, withIntermediateDirectories: true)
        guard let metadata = try? encoder.encode(song) else { return }
        try? metadata.write(to: preludeGiftSongMetadataURL)
        let audioURL = preludeGiftSongDirectory.appendingPathComponent(song.fileName)
        try? audioData.write(to: audioURL)
    }

    func loadPreludeGiftSong() -> PreludeGiftSong? {
        guard fileManager.fileExists(atPath: preludeGiftSongMetadataURL.path),
              let data = try? Data(contentsOf: preludeGiftSongMetadataURL),
              let song = try? decoder.decode(PreludeGiftSong.self, from: data) else {
            return nil
        }
        return song
    }

    func deletePreludeGiftSong() {
        try? fileManager.removeItem(at: preludeGiftSongDirectory)
        try? fileManager.createDirectory(at: preludeGiftSongDirectory, withIntermediateDirectories: true)
    }

    func preludeGiftSongAudioURL() -> URL {
        guard let song = loadPreludeGiftSong() else {
            return preludeGiftSongDirectory.appendingPathComponent("audio.m4a")
        }
        return preludeGiftSongDirectory.appendingPathComponent(song.fileName)
    }

    // MARK: - Archive

    func saveArchiveBundle(_ bundle: ArchiveBundle) {
        guard let data = try? encoder.encode(bundle) else { return }
        try? data.write(to: archiveBundleFileURL)
    }

    func loadArchiveBundle() -> ArchiveBundle? {
        guard fileManager.fileExists(atPath: archiveBundleFileURL.path),
              let data = try? Data(contentsOf: archiveBundleFileURL),
              let bundle = try? decoder.decode(ArchiveBundle.self, from: data) else {
            return nil
        }
        return bundle
    }

    func deleteArchiveBundle() {
        try? fileManager.removeItem(at: archiveBundleFileURL)
    }

    func saveReconnectInvite(_ invite: BreakupReconnectInvite) {
        guard let data = try? encoder.encode(invite) else { return }
        try? data.write(to: reconnectInviteFileURL)
    }

    func loadReconnectInvite() -> BreakupReconnectInvite? {
        guard fileManager.fileExists(atPath: reconnectInviteFileURL.path),
              let data = try? Data(contentsOf: reconnectInviteFileURL),
              let invite = try? decoder.decode(BreakupReconnectInvite.self, from: data) else {
            return nil
        }
        return invite
    }

    func clearReconnectInvite() {
        try? fileManager.removeItem(at: reconnectInviteFileURL)
    }

    func setPendingPartnerInvite(_ pending: Bool) {
        userDefaults.set(pending, forKey: pendingPartnerInviteKey)
    }

    func hasPendingPartnerInvite() -> Bool {
        userDefaults.bool(forKey: pendingPartnerInviteKey)
    }

    func savePendingInviteCode(_ code: String) {
        userDefaults.set(code, forKey: pendingInviteCodeKey)
    }

    func loadPendingInviteCode() -> String? {
        userDefaults.string(forKey: pendingInviteCodeKey)
    }

    func savePendingInvitePartnerName(_ name: String) {
        userDefaults.set(name, forKey: pendingInvitePartnerNameKey)
    }

    func loadPendingInvitePartnerName() -> String? {
        userDefaults.string(forKey: pendingInvitePartnerNameKey)
    }

    func clearPendingInviteState() {
        userDefaults.removeObject(forKey: pendingPartnerInviteKey)
        userDefaults.removeObject(forKey: pendingInviteCodeKey)
        userDefaults.removeObject(forKey: pendingInvitePartnerNameKey)
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
    func setForeverUnlocked(_ unlocked: Bool) {
        userDefaults.set(unlocked, forKey: isPartnerUnlockedKey)
    }

    func isForeverUnlocked() -> Bool {
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

    /// Inviter display name from the partner invite deep link (`?from=`).
    func saveInviterName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        userDefaults.set(trimmed, forKey: inviterNameKey)
    }

    func loadInviterName() -> String? {
        guard let name = userDefaults.string(forKey: inviterNameKey) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func loadHasUnreadMail() -> Bool {
        userDefaults.bool(forKey: hasUnreadMailKey)
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
        try? fileManager.removeItem(at: partnerAvatarURL)
        try? fileManager.removeItem(at: preludeCapturesFileURL)
        try? fileManager.removeItem(at: preludeChapterFileURL)
        try? fileManager.removeItem(at: partnerGiftCapturesFileURL)
        try? fileManager.removeItem(at: preludeVoiceMemosDirectory)
        try? fileManager.removeItem(at: preludePhotosDirectory)
        try? fileManager.removeItem(at: preludeGiftSongDirectory)
        try? fileManager.removeItem(at: archiveBundleFileURL)
        try? fileManager.removeItem(at: reconnectInviteFileURL)
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
        userDefaults.removeObject(forKey: partnerEmailKey)
        userDefaults.removeObject(forKey: userEmailKey)
        userDefaults.removeObject(forKey: isPartnerAccountKey)
        userDefaults.removeObject(forKey: inviterNameKey)
        clearPendingInviteState()
        BackgroundMusicImporter.clearImportedSong()
        MomentVideoStore.shared.removeAll()
    }
}
