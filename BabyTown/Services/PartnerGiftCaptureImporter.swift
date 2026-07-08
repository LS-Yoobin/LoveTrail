import Foundation
import UIKit

/// Downloads partner prelude gift media from accept-invite signed URLs and
/// persists them locally so reveal and garden book views can show photos/audio.
enum PartnerGiftCaptureImporter {
    static func importCaptures(_ captures: [GiftRevealCapture]) async -> [PreludeCapture] {
        guard !captures.isEmpty else { return [] }

        var imported: [PreludeCapture] = []
        for capture in captures {
            let permanentPath = CovelaMediaPath.normalizePermanentPath(capture.photoPath)
                ?? CovelaMediaPath.normalizePermanentPath(capture.photoURL)

            var prelude = PreludeCapture(
                id: capture.id,
                type: capture.type,
                isIncludedInGift: true,
                noteText: capture.noteText,
                firstLabel: capture.firstLabel,
                reasonText: capture.reasonText,
                serverId: capture.serverId,
                remotePhotoPath: permanentPath
            )

            if let image = await importPhoto(for: capture, permanentPath: permanentPath, prelude: &prelude) {
                let photoId = UUID()
                DataPersistenceManager.shared.savePreludePhoto(image, photoId: photoId)
                switch capture.type {
                case .first:
                    prelude.firstPhotoId = photoId
                case .note:
                    prelude.notePhotoId = photoId
                default:
                    break
                }
            }

            if capture.type == .voiceMemo,
               let audioURLString = capture.audioURL,
               let audioURL = URL(string: audioURLString),
               let data = try? await URLSession.shared.data(from: audioURL).0 {
                let fileId = "\(capture.id.uuidString).m4a"
                DataPersistenceManager.shared.savePreludeVoiceMemo(data: data, fileId: fileId)
                prelude.voiceMemoFileId = fileId
            }

            imported.append(prelude)
        }

        if !imported.isEmpty {
            DataPersistenceManager.shared.savePartnerGiftCaptures(imported)
        }
        return imported
    }

    private static func importPhoto(
        for capture: GiftRevealCapture,
        permanentPath: String?,
        prelude: inout PreludeCapture
    ) async -> UIImage? {
        if let photoURL = capture.photoURL, CovelaMediaPath.isSignedS3URL(photoURL),
           let image = await PreludePhotoLoader.downloadImage(from: photoURL) {
            return image
        }

        if let permanentPath, !permanentPath.isEmpty {
            prelude.remotePhotoPath = permanentPath
            if let image = await PreludePhotoLoader.loadImage(for: prelude) {
                return image
            }
        }

        if let photoURL = capture.photoURL {
            print("[PartnerGiftCaptureImporter] photo download failed for capture \(capture.id) url=\(photoURL.prefix(80))…")
        } else if permanentPath != nil {
            print("[PartnerGiftCaptureImporter] photo download failed for capture \(capture.id) path=\(permanentPath ?? "")")
        }

        return nil
    }
}
