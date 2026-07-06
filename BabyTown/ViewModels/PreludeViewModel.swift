import Foundation
import Combine

@MainActor
final class PreludeViewModel: ObservableObject {

    @Published var captures: [PreludeCapture] = []
    @Published var stage: RelationshipStage = .prelude
    @Published var inviteSent: Bool = false
    /// (completed, total) media/capture uploads remaining while preparing an invite.
    /// Nil when no invite-prep upload is in progress.
    @Published var invitePrepProgress: (completed: Int, total: Int)?

    private let dpm = DataPersistenceManager.shared

    init() {
        load()
    }

    // MARK: - Load / Save

    func load() {
        captures = dpm.loadPreludeCaptures()
        sortCapturesForTimeline()
        let profile = dpm.loadCoupleProfile()
        stage = profile.relationshipStage
        inviteSent = profile.inviteSent
    }

    private func saveCaptures() {
        dpm.savePreludeCaptures(captures)
    }

    private func sortCapturesForTimeline() {
        captures.sort {
            let lhs = $0.timelineDate
            let rhs = $1.timelineDate
            if lhs != rhs { return lhs > rhs }
            return $0.createdAt > $1.createdAt
        }
    }

    private func saveStage() {
        var profile = dpm.loadCoupleProfile()
        profile.relationshipStage = stage
        profile.inviteSent = inviteSent
        dpm.saveCoupleProfile(profile)
    }

    // MARK: - Capture CRUD

    func addCapture(_ capture: PreludeCapture) {
        captures.append(capture)
        sortCapturesForTimeline()
        saveCaptures()
        syncCaptureCreateOrUpdate(capture)
    }

    func updateCapture(_ capture: PreludeCapture) {
        guard let idx = captures.firstIndex(where: { $0.id == capture.id }) else { return }
        captures[idx] = capture
        sortCapturesForTimeline()
        saveCaptures()
        syncCaptureCreateOrUpdate(capture)
    }

    func deleteCapture(_ capture: PreludeCapture) {
        if let fileId = capture.voiceMemoFileId {
            dpm.deletePreludeVoiceMemo(fileId: fileId)
        }
        if let photoId = capture.firstPhotoId {
            dpm.deletePreludePhoto(photoId: photoId)
        }
        captures.removeAll { $0.id == capture.id }
        saveCaptures()
        syncDelete(capture)
    }

    func toggleGiftInclusion(for capture: PreludeCapture) {
        guard let idx = captures.firstIndex(where: { $0.id == capture.id }) else { return }
        captures[idx].isIncludedInGift.toggle()
        saveCaptures()
        syncGiftInclusion(captures[idx])
    }

    // MARK: - Gift

    var giftCaptures: [PreludeCapture] {
        captures.filter { $0.isIncludedInGift && !$0.isPartnerRetroactive }
    }

    /// Ensures every gift capture has a `serverId`, uploading any that are still local-only.
    /// Call right before `create-invite` so `gift_capture_ids` are all valid.
    func syncGiftCapturesForInvite() async throws -> [String] {
        let toSync = giftCaptures
        guard !toSync.isEmpty else { return [] }
        defer { invitePrepProgress = nil }
        let synced = try await PreludeAPIClient.shared.syncAllCaptures(toSync) { [weak self] completed, total in
            self?.invitePrepProgress = (completed, total)
        }
        for updated in synced {
            if let idx = captures.firstIndex(where: { $0.id == updated.id }) {
                captures[idx].serverId = updated.serverId
                captures[idx].remotePhotoPath = updated.remotePhotoPath
                captures[idx].remoteVoiceMemoPath = updated.remoteVoiceMemoPath
            }
        }
        saveCaptures()
        return synced.compactMap(\.serverId)
    }

    // MARK: - Backend sync (fire-and-forget)

    private func syncCaptureCreateOrUpdate(_ capture: PreludeCapture) {
        guard AuthService.shared.isSignedIn else { return }
        Task {
            do {
                let synced: PreludeCapture
                if capture.serverId != nil {
                    synced = try await PreludeAPIClient.shared.updateCapture(capture)
                } else {
                    synced = try await PreludeAPIClient.shared.createCapture(capture)
                }
                guard let idx = captures.firstIndex(where: { $0.id == capture.id }) else { return }
                captures[idx].serverId = synced.serverId
                captures[idx].remotePhotoPath = synced.remotePhotoPath
                captures[idx].remoteVoiceMemoPath = synced.remoteVoiceMemoPath
                saveCaptures()
            } catch {
                print("[PreludeViewModel] capture sync failed: \(error)")
            }
        }
    }

    private func syncGiftInclusion(_ capture: PreludeCapture) {
        guard AuthService.shared.isSignedIn, let serverId = capture.serverId else { return }
        Task {
            do {
                try await PreludeAPIClient.shared.updateGiftInclusion(serverId: serverId, isIncluded: capture.isIncludedInGift)
            } catch {
                print("[PreludeViewModel] gift inclusion sync failed: \(error)")
            }
        }
    }

    private func syncDelete(_ capture: PreludeCapture) {
        guard AuthService.shared.isSignedIn, let serverId = capture.serverId else { return }
        Task {
            do {
                try await PreludeAPIClient.shared.deleteCapture(serverId: serverId)
            } catch {
                print("[PreludeViewModel] capture delete sync failed: \(error)")
            }
        }
    }

    // MARK: - Stage Transitions

    func sendInvite() {
        inviteSent = true
        saveStage()
    }

    func transitionToOfficial(partnerUserId: String = "partner") {
        let firstCaptureDate = captures.map(\.timelineDate).min() ?? Date()
        let chapter = PreludeChapter(
            startDate: firstCaptureDate,
            officialDate: Date(),
            creatorUserId: "local",
            partnerUserId: partnerUserId,
            giftCaptureIds: giftCaptures.map(\.id)
        )
        dpm.savePreludeChapter(chapter)
        stage = .officialCouple
        inviteSent = false
        saveStage()
    }

    func archiveRelationship() {
        stage = .archivedCouple
        saveStage()
    }

    func reconnect() {
        stage = .officialCouple
        saveStage()
    }

    // MARK: - Partner Retroactive

    func addPartnerRetroactiveCapture(_ capture: PreludeCapture) {
        let updated = PreludeCapture(
            id: capture.id,
            createdAt: capture.createdAt,
            type: capture.type,
            isIncludedInGift: true,
            isPartnerRetroactive: true,
            noteText: capture.noteText,
            noteMood: capture.noteMood,
            notePhotoId: capture.notePhotoId,
            firstLabel: capture.firstLabel,
            firstPhotoId: capture.firstPhotoId,
            voiceMemoFileId: capture.voiceMemoFileId,
            reasonText: capture.reasonText,
            firstDate: capture.firstDate
        )
        captures.append(updated)
        saveCaptures()
    }

    // MARK: - Reflection Prompts

    static let notePrompts: [String] = [
        "What made you think about them today?",
        "What surprised you about them this week?",
        "What do you like about who you are when you're around them?",
        "What's something small they did that you keep thinking about?"
    ]

    static let firstOptionPages: [[String]] = [
        [
            "First text conversation",
            "First time they made you laugh",
            "First date",
            "First time you thought \"I'm in trouble\"",
            "First time you felt nervous around them",
            "First time you imagined a future with them"
        ],
        [
            "First kiss",
            "First time you said \"I love you\"",
            "First time meeting their friends",
            "First road trip together",
            "First time you stayed up all night talking",
            "First time you missed them"
        ],
        [
            "First time you held hands",
            "First time they cooked for you",
            "First time you met their family",
            "First time you danced together",
            "First time you felt truly seen",
            "First time you couldn't stop smiling"
        ]
    ]

    static var firstOptions: [String] { firstOptionPages[0] }

    static let reasonPrompt = "One reason I'm falling for you:"

    static let voicePrompts: [String] = [
        "What's on your mind about them right now?",
        "Say something you haven't had the words to text",
        "Tell them how a moment this week actually felt",
        "What would you say if they were sitting right here?",
        "Describe the feeling — not the story"
    ]
}
