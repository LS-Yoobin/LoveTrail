import Foundation

/// Registers this device's APNs token with the Covela backend so the inviter
/// can be pushed when their partner accepts an invite.
final class DeviceAPIClient {
    static let shared = DeviceAPIClient()

    private let client: CovelaAPIClient

    init(client: CovelaAPIClient = .shared) {
        self.client = client
    }

    private struct OKResponse: Decodable {
        let ok: Bool
    }

    func registerPushToken(_ hexToken: String) async {
        guard let token = await AuthService.shared.authToken else { return }
        do {
            let _: OKResponse = try await client.post(
                path: "device/push-token",
                body: ["iosPushToken": hexToken, "deviceType": "ios"],
                token: token
            )
        } catch {
            print("[DeviceAPIClient] Failed to register push token: \(error)")
        }
    }
}
