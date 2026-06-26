import SwiftUI

struct StopDetailSheet: View {
    let stop: ItineraryStop
    var showsRemoveAction: Bool = true
    let onRemove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showCopied = false

    private var mapsURL: URL? {
        if let lat = stop.latitude, let lon = stop.longitude {
            let query = stop.placeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://maps.apple.com/?ll=\(lat),\(lon)&q=\(query)")
        } else {
            let query = stop.placeName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://maps.apple.com/?q=\(query)")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Place info
            VStack(spacing: 6) {
                if let data = stop.photoData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 4)
                } else {
                    ZStack {
                        BabyTownTheme.accentSoft
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 24))
                            .foregroundStyle(BabyTownTheme.accent)
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.bottom, 4)
                }

                Text(stop.placeName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                    .multilineTextAlignment(.center)

                if let address = stop.address, !address.isEmpty {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(BabyTownTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 24)

            // Action buttons
            HStack(spacing: 12) {
                actionButton(icon: "arrow.triangle.turn.up.right.circle.fill", label: "Navigate") {
                    if let url = mapsURL {
                        UIApplication.shared.open(url)
                    }
                }

                actionButton(icon: "link.circle.fill", label: showCopied ? "Copied" : "Copy Link") {
                    if let url = mapsURL {
                        UIPasteboard.general.string = url.absoluteString
                        withAnimation { showCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showCopied = false }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer()

            if showsRemoveAction {
                Button {
                    onRemove()
                    dismiss()
                } label: {
                    Text("Remove Stop")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            } else {
                Color.clear
                    .frame(height: 32)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundStyle(BabyTownTheme.accent)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(BabyTownTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
