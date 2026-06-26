import SwiftUI

struct HomeGardenPatchView: View {
    let hasUnreadMail: Bool
    let onPetHouseTap: () -> Void
    let onMailboxTap: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("home_grass_patch")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)

            HStack(alignment: .bottom, spacing: 0) {
                Button(action: onPetHouseTap) {
                    Image("home_pet_house")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 90)
                }
                .buttonStyle(.plain)
                .padding(.leading, 28)

                Spacer()

                Button(action: onMailboxTap) {
                    Image(hasUnreadMail ? "home_mailbox_full" : "home_mailbox_empty")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 70)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 36)
            }
            .offset(y: 14)
        }
        .frame(height: 160)
        .clipped()
    }
}

#Preview {
    VStack {
        HomeGardenPatchView(
            hasUnreadMail: false,
            onPetHouseTap: {},
            onMailboxTap: {}
        )
        HomeGardenPatchView(
            hasUnreadMail: true,
            onPetHouseTap: {},
            onMailboxTap: {}
        )
    }
    .padding()
    .background(Color(red: 0.94, green: 0.97, blue: 1.0))
}
