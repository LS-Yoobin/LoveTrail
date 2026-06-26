//
//  BabyTownApp.swift
//  BabyTown
//
//  Created by Justin Seo on 2/12/26.
//

import SwiftUI

@main
struct BabyTownApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        _ = DataPersistenceManager.shared.loadOrCreateAppJoinedDate()
        _ = CouplePlaylistStore.tracks
        Task { @MainActor in
            CoupleMusicPlaybackState.shared.refreshFromStore()
            if CouplePlaylistStore.hasTracks, AudioManager.shared.gardenIsActive {
                AudioManager.shared.reloadGardenMusic()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
