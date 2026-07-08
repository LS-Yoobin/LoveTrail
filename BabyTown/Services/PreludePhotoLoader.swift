import Foundation
import UIKit

/// Loads prelude capture photos from on-device storage, or from covela-fs when the
/// partner received gift captures from the server (signed URL at import, or permanent path).
enum PreludePhotoLoader {
    #if DEBUG
    enum PhotoLoadSource: String, CaseIterable {
        case localFirst = "local"
        case remoteFirst = "remote"

        var label: String {
            switch self {
            case .localFirst: return "Local"
            case .remoteFirst: return "Remote signed URL"
            }
        }
    }

    private static let debugPhotoLoadSourceKey = "debugPreludePhotoLoadSource"

    static var debugPhotoLoadSource: PhotoLoadSource {
        get {
            guard let raw = UserDefaults.standard.string(forKey: debugPhotoLoadSourceKey),
                  let source = PhotoLoadSource(rawValue: raw) else {
                return .localFirst
            }
            return source
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: debugPhotoLoadSourceKey)
        }
    }
    #endif

    static func loadImage(for capture: PreludeCapture) async -> UIImage? {
        let dpm = DataPersistenceManager.shared
        let photoId = capture.firstPhotoId ?? capture.notePhotoId

        #if DEBUG
        if debugPhotoLoadSource == .remoteFirst {
            if let remote = await loadRemoteImage(for: capture) {
                print("[PreludePhotoLoader] DEBUG remote signed URL OK capture=\(capture.id)")
                return remote
            }
            if let photoId, let local = dpm.loadPreludePhoto(photoId: photoId) {
                print("[PreludePhotoLoader] DEBUG remote failed, using local capture=\(capture.id)")
                return local
            }
            return nil
        }
        #endif

        if let photoId, let local = dpm.loadPreludePhoto(photoId: photoId) {
            return local
        }

        return await loadRemoteImage(for: capture)
    }

    private static func loadRemoteImage(for capture: PreludeCapture) async -> UIImage? {
        guard let remotePath = capture.remotePhotoPath, !remotePath.isEmpty else { return nil }

        if CovelaMediaPath.isSignedS3URL(remotePath),
           let image = await downloadImage(from: remotePath) {
            return image
        }
        if let normalized = CovelaMediaPath.normalizePermanentPath(remotePath),
           let image = await downloadAndCache(path: normalized, capture: capture) {
            return image
        }
        return nil
    }

    static func downloadImage(from urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else { return nil }
            guard (200...299).contains(http.statusCode) else {
                print("[PreludePhotoLoader] direct URL download HTTP \(http.statusCode) for \(urlString.prefix(80))…")
                return nil
            }
            return UIImage(data: data)
        } catch {
            print("[PreludePhotoLoader] direct URL download failed: \(error)")
            return nil
        }
    }

    private static func downloadAndCache(path: String, capture: PreludeCapture) async -> UIImage? {
        guard let token = await AuthService.shared.authToken else { return nil }
        do {
            let signedURL = try await CovelaAPIClient.shared.signedMediaURL(forPath: path, token: token)
            let (data, response) = try await URLSession.shared.data(from: signedURL)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let image = UIImage(data: data) else {
                return nil
            }

            let photoId = capture.firstPhotoId ?? capture.notePhotoId ?? UUID()
            DataPersistenceManager.shared.savePreludePhoto(image, photoId: photoId)
            cachePhotoId(photoId, for: capture)
            return image
        } catch {
            print("[PreludePhotoLoader] signed URL load failed for capture \(capture.id): \(error)")
            return nil
        }
    }

    private static func cachePhotoId(_ photoId: UUID, for capture: PreludeCapture) {
        var updated = capture
        switch capture.type {
        case .first:
            updated.firstPhotoId = photoId
        case .note:
            updated.notePhotoId = photoId
        default:
            return
        }

        var partnerCaptures = DataPersistenceManager.shared.loadPartnerGiftCaptures()
        if let index = partnerCaptures.firstIndex(where: { $0.id == capture.id }) {
            partnerCaptures[index] = updated
            DataPersistenceManager.shared.savePartnerGiftCaptures(partnerCaptures)
            return
        }

        var ownCaptures = DataPersistenceManager.shared.loadPreludeCaptures()
        if let index = ownCaptures.firstIndex(where: { $0.id == capture.id }) {
            ownCaptures[index] = updated
            DataPersistenceManager.shared.savePreludeCaptures(ownCaptures)
        }
    }
}
