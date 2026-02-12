import Foundation
import Combine
import SwiftUI
import PhotosUI

@MainActor
final class FirstMemoriesViewModel: ObservableObject {

    @Published var firstMetImage: UIImage?
    @Published var officialImage: UIImage?
    @Published var heroImage: UIImage?

    @Published var firstMetItem: PhotosPickerItem?
    @Published var officialItem: PhotosPickerItem?

    var canFinish: Bool {
        officialImage != nil
    }

    func handleFirstMetSelection() async {
        guard let image = await loadImage(from: firstMetItem) else { return }
        firstMetImage = image
        heroImage = image
    }

    func handleOfficialSelection() async {
        guard let image = await loadImage(from: officialItem) else { return }
        officialImage = image
        heroImage = image
    }

    private func loadImage(from item: PhotosPickerItem?) async -> UIImage? {
        guard let item else { return nil }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return UIImage(data: data)
    }
}
