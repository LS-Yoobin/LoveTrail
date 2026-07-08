import Foundation

/// Shared code-redemption logic used by every screen that lets a user join
/// with a partner's invite code (the pre-pathSelector check and the
/// in-onboarding fallback both call into this).
enum InviteJoinFlow {

    enum Outcome {
        case joined(captures: [PreludeCapture], revealerName: String)
        /// `alreadyPaired` is true when the failure means this account is
        /// already an official couple — callers should route to Home instead
        /// of just displaying `message`.
        case failure(message: String, alreadyPaired: Bool = false)
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
            DataPersistenceManager.shared.saveInviterName(response.revealerName)
            DataPersistenceManager.shared.setPartnerAccount(true)
            let captures = await PartnerGiftCaptureImporter.importCaptures(response.revealCaptures)
            DataPersistenceManager.shared.recordPreludeChapterIfNeeded()
            return .joined(captures: captures, revealerName: response.revealerName)
        } catch {
            return .failure(
                message: InviteErrorMapper.message(for: error),
                alreadyPaired: InviteErrorMapper.isAlreadyPaired(error)
            )
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
