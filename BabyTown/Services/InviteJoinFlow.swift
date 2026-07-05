import Foundation

/// Shared code-redemption logic used by every screen that lets a user join
/// with a partner's invite code (the pre-pathSelector check and the
/// in-onboarding fallback both call into this).
enum InviteJoinFlow {

    enum Outcome {
        case joined(captures: [GiftRevealCapture], revealerName: String)
        case failure(message: String)
    }

    static func join(code: String) async -> Outcome {
        do {
            let lookup = try await InviteAPI.client.checkInviteStatus(code: code)
            guard lookup.valid else {
                return .failure(message: errorMessage(forInvalidStatus: lookup.status))
            }
            let response = try await InviteAPI.client.acceptInvite(code: code)
            var profile = DataPersistenceManager.shared.loadCoupleProfile()
            profile.relationshipStage = .officialCouple
            DataPersistenceManager.shared.saveCoupleProfile(profile)
            DataPersistenceManager.shared.clearPendingInviteState()
            return .joined(captures: response.revealCaptures, revealerName: response.revealerName)
        } catch {
            return .failure(message: InviteErrorMapper.message(for: error))
        }
    }

    private static func errorMessage(forInvalidStatus status: InviteStatusResponse.Status?) -> String {
        switch status {
        case .expired: return "That code has expired."
        case .cancelled: return "That code has been cancelled."
        case .accepted: return "That invite has already been used."
        case .pending, nil: return "That code is not valid."
        }
    }
}
