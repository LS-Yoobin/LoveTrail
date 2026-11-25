import Foundation

/// Registers every synced resource with the engine. Call once at launch, before the
/// first `sync(trigger:)`.
@MainActor
enum CoupleSyncBootstrap {
    private static var didRegister = false

    static func registerResources() {
        guard !didRegister else { return }
        didRegister = true
        let engine = CoupleSyncEngine.shared
        // Order matters: resources that reference moments pull after moments.
        engine.register(SpecialDatesSyncResource())
        engine.register(CoupleProfileSyncResource())
        engine.register(MomentsSyncResource())
        engine.register(PolaroidsSyncResource())
        // After moments: canvases and stickers point at moments.
        engine.register(MemoryCanvasSyncResource())
        engine.register(StickersSyncResource())
        engine.register(PlaylistSyncResource())
        // Off until the BAB-63 endpoint is verified against the BAB-54 contract.
        if DatePlansSyncResource.isNetworkSyncEnabled {
            engine.register(DatePlansSyncResource())
        }
        engine.register(PetSyncResource())
        engine.register(PetRoomSyncResource())
        engine.register(PetTricksSyncResource())
        engine.register(CoinLedgerSync.shared)
        engine.register(LettersSyncResource.shared as CoupleSyncCollection)
        engine.register(LettersSyncResource.shared as CoupleSyncTask)
    }
}
