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

        ensure(.userAvatar, sourceKey: "userAvatar", image: dpm.loadUserAvatar(),
               defaultPosition: ProfileSticker.defaultUserAvatarPosition)

        ensurePartnerInviteSticker(stickers: &stickers, bySource: &bySource, dpm: dpm)

        if let idx = stickers.firstIndex(where: { $0.kind == .userAvatar }),
           Self.isLegacyUserAvatarPosition(stickers[idx].position) {
            stickers[idx].position = ProfileSticker.defaultUserAvatarPosition
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

    /// Guarantees exactly one persistent partner-invite sticker. It renders a heart
    /// placeholder (no stored image) and is draggable like any other sticker.
    private static func ensurePartnerInviteSticker(
        stickers: inout [ProfileSticker],
        bySource: inout [String: ProfileSticker],
        dpm: DataPersistenceManager
    ) {
        let existing = stickers.filter { $0.kind == .partnerInvite }
        // Collapse any duplicates down to the first; delete extras' images.
        if existing.count > 1 {
            for extra in existing.dropFirst() {
                dpm.deleteStickerImage(id: extra.id)
            }
            let keepID = existing.first!.id
            stickers.removeAll { $0.kind == .partnerInvite && $0.id != keepID }
        }
        if existing.isEmpty {
            let sticker = ProfileSticker(
                kind: .partnerInvite,
                sourceKey: "partnerInvite",
                position: ProfileSticker.defaultPartnerPosition,
                rotation: 0,
                scale: ProfileSticker.defaultScale
            )
            stickers.append(sticker)
            bySource[sticker.sourceKey] = sticker
        }
    }

    private static func isLegacyUserAvatarPosition(_ point: NormalizedPoint) -> Bool {
        abs(point.x - 0.28) < 0.02 && abs(point.y - 0.24) < 0.02
    }

    private static func specialDateDefaultPosition(for key: String, existing: [ProfileSticker]) -> NormalizedPoint {
        let specials = existing.filter { $0.kind == .specialDate }
        let index = specials.count
        let x = 0.18 + CGFloat(index % 3) * 0.20
        let y = 0.30 + CGFloat(index / 3) * 0.10
        _ = key
        return NormalizedPoint(x: min(x, 0.72), y: min(y, 0.44))
    }
}
