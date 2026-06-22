import SwiftUI

struct ScrapbookPetView: View {
    let bundle: ArchiveBundle

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            if let skin = bundle.petState.adoptedSkin {
                Image(skin.portraitAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                Text(bundle.petState.customPetNames[skin.rawValue] ?? skin.petName)
                    .font(.title3.bold())
                Text("Resting peacefully")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("No pet adopted yet")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
