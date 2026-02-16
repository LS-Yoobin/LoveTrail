import SwiftUI

struct PolaroidCameraView: View {

    @ObservedObject var polaroidStore: LocalPolaroidStore
    @Environment(\.dismiss) private var dismiss
    var onPhotosReleased: ([PolaroidEntry]) -> Void

    @StateObject private var locationManager = CameraLocationManager()
    @State private var capturedImage: UIImage?
    @State private var showNotification = false
    @State private var notificationMessage = ""
    @State private var showLogModal = false
    @State private var showReleaseConfirmation = false

    @AppStorage("currentCatVariantIndex") private var currentCatVariantIndex = 1

    private var todaysCount: Int {
        polaroidStore.todaysCaptureCount()
    }

    private var hasUnreleasedToday: Bool {
        !polaroidStore.todaysUnreleasedEntries().isEmpty
    }

    var body: some View {
        ZStack {
            CustomCameraView(image: $capturedImage, canCapture: true)
                .ignoresSafeArea()

            VStack {
                topBar

                Spacer()

                if showNotification {
                    notificationBanner
                        .padding(.bottom, 120)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear { locationManager.requestPermissionAndStart() }
        .onDisappear { locationManager.stop() }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                capturedImage = nil
                Task {
                    await handleCapturedPhoto(image)
                }
            }
        }
        .sheet(isPresented: $showLogModal) {
            CameraLogView(entries: polaroidStore.todaysUnreleasedEntries())
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 17, weight: .medium))
                }
                .foregroundStyle(.white)
            }

            Spacer()

            Button(action: { showLogModal = true }) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let lastEntry = polaroidStore.todaysUnreleasedEntries().last,
                           let image = polaroidStore.loadImage(for: lastEntry) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Color.black.opacity(0.3)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white.opacity(0.7))
                                )
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.5), lineWidth: 1)
                    )
                    
                    if todaysCount > 0 {
                        Text("\(todaysCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(Color(red: 0.95, green: 0.26, blue: 0.35))
                                    .shadow(color: .black.opacity(0.2), radius: 2)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var notificationBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                Text(notificationMessage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text("Take another photo if you'd like")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 24)
    }

    private var releaseButton: some View {
        Button {
            showReleaseConfirmation = true
        } label: {
            Text("Add to Baby Town Now")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .strokeBorder(.white, lineWidth: 2)
                        .background(Capsule().fill(.black.opacity(0.4)))
                )
        }
        .alert("Are you sure?", isPresented: $showReleaseConfirmation) {
            Button("No", role: .cancel) { }
            Button("Yes") {
                releaseNow()
            }
        }
    }

    private func handleCapturedPhoto(_ image: UIImage) async {
        var placeName: String? = nil
        let location = locationManager.currentLocation
        if let location = location {
            placeName = await SmartPlaceResolver.shared.resolvePlaceName(for: location)
        }

        guard polaroidStore.savePhoto(image, placeName: placeName, location: location) != nil else { return }

        notificationMessage = "This photo will be available later"

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showNotification = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation {
                showNotification = false
            }
        }
    }

    private func releaseNow() {
        let toRelease = polaroidStore.todaysUnreleasedEntries()
        polaroidStore.releaseEntriesManually(toRelease)
        onPhotosReleased(toRelease)
        dismiss()
    }

    private func rotateCatVariant() {
        if currentCatVariantIndex < 5 {
            currentCatVariantIndex += 1
        } else {
            currentCatVariantIndex = 1
        }
    }
}
