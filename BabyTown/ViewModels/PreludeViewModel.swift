import Foundation
import Combine

@MainActor
final class PreludeViewModel: ObservableObject {

    @Published var captures: [PreludeCapture] = []
    @Published var stage: RelationshipStage = .prelude
    @Published var inviteSent: Bool = false

    private let dpm = DataPersistenceManager.shared

    init() {
        load()
    }

    // MARK: - Load / Save

    func load() {
        captures = dpm.loadPreludeCaptures()
        let profile = dpm.loadCoupleProfile()
        stage = profile.relationshipStage
        inviteSent = profile.inviteSent
    }

    private func saveCaptures() {
        dpm.savePreludeCaptures(captures)
    }

    private func saveStage() {
        var profile = dpm.loadCoupleProfile()
        profile.relationshipStage = stage
        profile.inviteSent = inviteSent
        dpm.saveCoupleProfile(profile)
    }

    // MARK: - Capture CRUD

    func addCapture(_ capture: PreludeCapture) {
        captures.insert(capture, at: 0)
        saveCaptures()
    }

    func updateCapture(_ capture: PreludeCapture) {
        guard let idx = captures.firstIndex(where: { $0.id == capture.id }) else { return }
        captures[idx] = capture
        saveCaptures()
    }

    func deleteCapture(_ capture: PreludeCapture) {
        if let fileId = capture.voiceMemoFileId {
            dpm.deletePreludeVoiceMemo(fileId: fileId)
        }
        captures.removeAll { $0.id == capture.id }
        saveCaptures()
    }

    func toggleGiftInclusion(for capture: PreludeCapture) {
        guard let idx = captures.firstIndex(where: { $0.id == capture.id }) else { return }
        captures[idx].isIncludedInGift.toggle()
        saveCaptures()
    }

    // MARK: - Gift

    var giftCaptures: [PreludeCapture] {
        captures.filter { $0.isIncludedInGift && !$0.isPartnerRetroactive }
    }

    // MARK: - Stage Transitions

    func sendInvite() {
        inviteSent = true
        saveStage()
    }

    func transitionToOfficial(partnerUserId: String = "partner") {
        let firstCaptureDate = captures.map(\.createdAt).min() ?? Date()
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
            notePhotoId: capture.notePhotoId,
            firstLabel: capture.firstLabel,
            voiceMemoFileId: capture.voiceMemoFileId,
            reasonText: capture.reasonText
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

    static let firstOptions: [String] = [
        "First text conversation",
        "First time they made you laugh",
        "First date",
        "First time you thought \"I'm in trouble\"",
        "First time you felt nervous around them",
        "First time you imagined a future with them"
    ]

    static let reasonPrompt = "One reason I'm falling for you:"
}
