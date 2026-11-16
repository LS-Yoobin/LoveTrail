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
        engine.register(PlaylistSyncResource())
        engine.register(PetSyncResource())
        engine.register(PetRoomSyncResource())
        engine.register(PetTricksSyncResource())
        engine.register(CoinLedgerSync.shared)
    }
}
