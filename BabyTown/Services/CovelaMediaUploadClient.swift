import Foundation
import UIKit

enum CovelaFileServerConfig {
    /// Override at runtime with the `COVELA_FILE_SERVER_BASE_URL` environment variable (Xcode scheme).
    /// Same Heroku app as the LinkedSpaces file server, different namespace.
    static var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["COVELA_FILE_SERVER_BASE_URL"],
           let url = URL(string: override) {
            return url
        }
        return URL(string: "https://ls-file-server-4312402ca23f.herokuapp.com/COVELA_FS_API")!
    }
}

enum CovelaMediaUploadError: LocalizedError {
    case notSignedIn
    case invalidResponse
    /// The request never completed (offline, timeout). Safe to retry later.
    case network
    /// The file server refused this file (`result: false`, 4xx). Retrying won't help.
    case rejected(String?)
    case serializationFailed
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Please sign in to upload media."
        case .invalidResponse: return "Unexpected response from the file server."
        case .network: return "Couldn't reach the file server."
        case .rejected(let reason): return "The file server refused the file\(reason.map { " (\($0))" } ?? "")."
        case .serializationFailed: return "Failed to prepare the file for upload."
        case .httpError(let code, let message): return "Upload failed (\(code)): \(message)"
        }
    }
}

/// Uploads Covela prelude media (photos/voice memos) to ls-file-server's
/// `/COVELA_FS_API/media/file_upload`, returning the permanent covela-fs S3 key.
/// Mirrors the LinkedSpaces upload pattern (see APIManager.uploadPhoto in the Bloggo app):
/// upload once, store the permanent key, and resolve it to a signed URL only when displaying.
final class CovelaMediaUploadClient {
    static let shared = CovelaMediaUploadClient()

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    private struct UploadResponse: Decodable {
        let path: String?
        let result: Bool?
        let reason: String?
    }

    private func requireToken() async throws -> String {
        guard let token = await AuthService.shared.authToken else {
            throw CovelaMediaUploadError.notSignedIn
        }
        return token
    }

    /// Uploads a JPEG photo. `quality` is 1-100 (default 80).
    func uploadPhoto(_ image: UIImage, filename: String = "photo.jpg", quality: Int = 80) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.92) else {
            throw CovelaMediaUploadError.serializationFailed
        }
        return try await upload(fieldName: "photo", fileName: filename, contentType: "image/jpeg", data: imageData, quality: quality)
    }

    /// Uploads already-encoded JPEG bytes as-is (no re-encode), so the same file
    /// always produces the same fingerprint for sync.
    func uploadJPEGData(_ data: Data, filename: String = "photo.jpg", quality: Int = 80) async throws -> String {
        try await upload(fieldName: "photo", fileName: filename, contentType: "image/jpeg", data: data, quality: quality)
    }

    /// Uploads arbitrary file bytes under the given multipart field.
    func uploadFileData(_ data: Data, fieldName: String, filename: String, contentType: String) async throws -> String {
        try await upload(fieldName: fieldName, fileName: filename, contentType: contentType, data: data, quality: nil)
    }

    /// Uploads a video file (`.mov` or `.mp4`) as-is (BAB-144, max 100 MB).
    func uploadVideo(_ data: Data, filename: String) async throws -> String {
        let contentType = filename.lowercased().hasSuffix(".mp4") ? "video/mp4" : "video/quicktime"
        return try await upload(fieldName: "video", fileName: filename, contentType: contentType, data: data, quality: nil)
    }

    /// Uploads a transparent PNG cutout; the file server keeps it PNG (BAB-144, max 10 MB).
    func uploadSticker(_ data: Data, filename: String = "sticker.png") async throws -> String {
        try await upload(fieldName: "sticker", fileName: filename, contentType: "image/png", data: data, quality: nil)
    }

    /// Uploads a voice memo (m4a/AAC).
    func uploadVoiceMemo(_ data: Data, filename: String = "voice.m4a") async throws -> String {
        try await upload(fieldName: "audio", fileName: filename, contentType: "audio/m4a", data: data, quality: nil)
    }

    private func upload(fieldName: String, fileName: String, contentType: String, data: Data, quality: Int?) async throws -> String {
        let token = try await requireToken()
        let url = CovelaFileServerConfig.baseURL.appendingPathComponent("media/file_upload")

        let boundary = UUID().uuidString
        var body = Data()
        if let quality {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"quality\"\r\n\r\n".utf8))
            body.append(Data("\(quality)\r\n".utf8))
        }
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(contentType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        print("[CovelaMediaUploadClient] POST \(url.absoluteString) — \(fieldName): \(fileName) (\(data.count) bytes)")

        let (responseData, response): (Data, URLResponse)
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw CovelaMediaUploadError.network
        }

        guard let http = response as? HTTPURLResponse else {
            throw CovelaMediaUploadError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            let message = String(data: responseData, encoding: .utf8) ?? "Upload failed."
            if (400..<500).contains(http.statusCode) {
                throw CovelaMediaUploadError.rejected(message)
            }
            throw CovelaMediaUploadError.httpError(http.statusCode, message)
        }

        guard let decoded = try? JSONDecoder().decode(UploadResponse.self, from: responseData) else {
            throw CovelaMediaUploadError.invalidResponse
        }
        guard decoded.result != false, let path = decoded.path, !path.isEmpty else {
            throw CovelaMediaUploadError.rejected(decoded.reason)
        }
        print("[CovelaMediaUploadClient] uploaded → \(path)")
        return path
    }
}
