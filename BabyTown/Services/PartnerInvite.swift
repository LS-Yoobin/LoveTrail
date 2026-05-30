import Foundation

/// A partner invite: a stable per-user code and the link/message built from it.
///
/// The link is a placeholder until the partner-join backend exists; the code is
/// generated once and persisted so it stays stable when that backend lands.
struct PartnerInvite {

    let code: String

    var link: String {
        "https://babytown.app/invite/\(code)"
    }

    var messageText: String {
        "Join me in Baby Town 💞 — our private space for just the two of us. Tap to join: \(link)"
    }

    /// The current user's invite, creating + persisting a code on first use.
    static func current() -> PartnerInvite {
        PartnerInvite(code: DataPersistenceManager.shared.loadOrCreatePartnerInviteCode())
    }

    /// 6 characters from an unambiguous alphabet (no 0/O/1/I).
    static func generateCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement()! })
    }
}
