import UIKit

/// Keeps `CoupleProfile.stickers` aligned with available photos (avatar, special
/// dates) and regenerates sticker cutout files when sources change.
enum ProfileStickerSync {

    static func sync(
        profile: inout CoupleProfile,
        dpm: DataPersistenceManager
    ) {
        var stickers = profile.stickers
        var bySource = Dictionary(uniqueKeysWithValues: stickers.map { ($0.sourceKey, $0) })

        func ensure(_ kind: ProfileSticker.Kind, sourceKey: String, image: UIImage?, defaultPosition: NormalizedPoint) {
            guard let image else {
                if let existing = bySource[sourceKey] {
                    dpm.deleteStickerImage(id: existing.id)
                    stickers.removeAll { $0.sourceKey == sourceKey }
                    bySource.removeValue(forKey: sourceKey)
                }
                return
            }
            if var sticker = bySource[sourceKey] {
                let processed = SubjectLiftService.stickerImage(from: image)
                dpm.saveStickerImage(processed.image, id: sticker.id)
                sticker.usedSubjectLift = processed.usedSubjectLift
                if let idx = stickers.firstIndex(where: { $0.sourceKey == sourceKey }) {
                    stickers[idx] = sticker
                }
                bySource[sourceKey] = sticker
            } else {
                let processed = SubjectLiftService.stickerImage(from: image)
                let sticker = ProfileSticker(
                    kind: kind,
                    sourceKey: sourceKey,
                    position: defaultPosition,
                    rotation: Double.random(in: -12...12),
                    scale: ProfileSticker.defaultScale,
                    usedSubjectLift: processed.usedSubjectLift
                )
                dpm.saveStickerImage(processed.image, id: sticker.id)
                stickers.append(sticker)
                bySource[sourceKey] = sticker
            }
        }

        syncUserAvatarSticker(stickers: &stickers, bySource: &bySource, dpm: dpm)

        dedupePartnerInviteStickers(stickers: &stickers, bySource: &bySource, dpm: dpm)

        if let idx = stickers.firstIndex(where: { $0.kind == .userAvatar }),
           Self.shouldMigrateToDefaultProfilePosition(stickers[idx].position, kind: .userAvatar) {
            stickers[idx].position = ProfileSticker.defaultUserAvatarPosition
        }

        if let idx = stickers.firstIndex(where: { $0.kind == .partnerInvite }),
           Self.shouldMigrateToDefaultProfilePosition(stickers[idx].position, kind: .partnerInvite) {
            stickers[idx].position = ProfileSticker.defaultPartnerPosition
        }

        for date in profile.specialDates {
            let key = date.id.uuidString
            ensure(.specialDate, sourceKey: key, image: dpm.loadSpecialDatePhoto(id: date.id),
                   defaultPosition: specialDateDefaultPosition(for: key, existing: stickers))
        }

        let validSpecialKeys = Set(profile.specialDates.map(\.id.uuidString))
        stickers.removeAll { sticker in
            guard sticker.kind == .specialDate else { return false }
            if validSpecialKeys.contains(sticker.sourceKey) { return false }
            dpm.deleteStickerImage(id: sticker.id)
            bySource.removeValue(forKey: sticker.sourceKey)
            return true
        }

        if let existing = bySource["pet"] {
            dpm.deleteStickerImage(id: existing.id)
            stickers.removeAll { $0.sourceKey == "pet" }
        }

        let validMomentKeys = Set(
            dpm.loadMoments().map(\.id.uuidString)
            + dpm.loadPromptMemories().flatMap { $0.photos.map(\.id.uuidString) }
        )
        stickers.removeAll { sticker in
            guard sticker.kind == .moment else { return false }
            if validMomentKeys.contains(sticker.sourceKey) { return false }
            dpm.deleteStickerImage(id: sticker.id)
            bySource.removeValue(forKey: sticker.sourceKey)
            return true
        }

        profile.stickers = stickers
        dpm.saveCoupleProfile(profile)
    }

    /// Legacy default for user avatar stickers (customize mode only).
    static let canonicalUserAvatarPosition = NormalizedPoint(x: 0.19, y: 0.138)

    /// Updates an existing user-avatar sticker cutout when the profile photo changes.
    /// Does **not** create a sticker if the user removed it from the garden.
    private static func syncUserAvatarSticker(
        stickers: inout [ProfileSticker],
        bySource: inout [String: ProfileSticker],
        dpm: DataPersistenceManager
    ) {
        let key = "userAvatar"
        guard var sticker = bySource[key] else { return }

        if let image = dpm.loadUserAvatar() {
            let processed = SubjectLiftService.stickerImage(from: image)
            dpm.saveStickerImage(processed.image, id: sticker.id)
            sticker.usedSubjectLift = processed.usedSubjectLift
        } else {
            dpm.deleteStickerImage(id: sticker.id)
            sticker.usedSubjectLift = false
        }
        if let idx = stickers.firstIndex(where: { $0.id == sticker.id }) {
            stickers[idx] = sticker
        }
        bySource[key] = sticker
    }

    /// Adds a user-avatar garden sticker after the user saves a profile photo.
    /// Call from the profile editor — not from routine `sync`.
    static func addUserAvatarStickerIfMissing(
        profile: inout CoupleProfile,
        dpm: DataPersistenceManager
    ) {
        let key = "userAvatar"
        guard profile.stickers.first(where: { $0.sourceKey == key }) == nil,
              let image = dpm.loadUserAvatar() else { return }

        var sticker = ProfileSticker(
            kind: .userAvatar,
            sourceKey: key,
            position: ProfileSticker.defaultUserAvatarPosition,
            rotation: 0,
            scale: ProfileSticker.defaultScale
        )
        let processed = SubjectLiftService.stickerImage(from: image)
        dpm.saveStickerImage(processed.image, id: sticker.id)
        sticker.usedSubjectLift = processed.usedSubjectLift
        profile.stickers.append(sticker)
    }

    /// Collapses duplicate partner-invite stickers only; never re-adds one the user removed.
    private static func dedupePartnerInviteStickers(
        stickers: inout [ProfileSticker],
        bySource: inout [String: ProfileSticker],
        dpm: DataPersistenceManager
    ) {
        let existing = stickers.filter { $0.kind == .partnerInvite }
        guard existing.count > 1 else { return }
        for extra in existing.dropFirst() {
            dpm.deleteStickerImage(id: extra.id)
            bySource.removeValue(forKey: extra.sourceKey)
        }
        let keepID = existing.first!.id
        stickers.removeAll { $0.kind == .partnerInvite && $0.id != keepID }
    }

    private static func shouldMigrateToDefaultProfilePosition(
        _ point: NormalizedPoint,
        kind: ProfileSticker.Kind
    ) -> Bool {
        if isLegacyUserAvatarPosition(point) { return kind == .userAvatar }
        let xs: [CGFloat] = kind == .userAvatar ? [0.30, 0.32] : [0.68, 0.70]
        guard xs.contains(where: { abs(point.x - $0) < 0.06 }) else { return false }
        // Legacy positions from earlier layout passes (including the brief above-cards band).
        return abs(point.y - 0.62) < 0.04
            || abs(point.y - 0.50) < 0.04
            || abs(point.y - 0.12) < 0.04
    }

    private static func isLegacyUserAvatarPosition(_ point: NormalizedPoint) -> Bool {
        abs(point.x - 0.28) < 0.02 && abs(point.y - 0.24) < 0.02
    }

    private static func specialDateDefaultPosition(for key: String, existing: [ProfileSticker]) -> NormalizedPoint {
        let specials = existing.filter { $0.kind == .specialDate }
        let index = specials.count
        let x = 0.18 + CGFloat(index % 3) * 0.20
        let y = 0.22 + CGFloat(index / 3) * 0.10
        _ = key
        return NormalizedPoint(x: min(x, 0.72), y: min(y, 0.36))
    }
}
