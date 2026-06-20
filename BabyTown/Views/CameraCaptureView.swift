import SwiftUI

struct CameraCaptureView: View {

    @ObservedObject var polaroidStore: LocalPolaroidStore
    @Environment(\.dismiss) private var dismiss
    var onPhotosReleased: ([PolaroidEntry]) -> Void

    @StateObject private var locationManager = CameraLocationManager()
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showNotification = false
    @State private var notificationMessage = ""
    @State private var showReleaseConfirmation = false

    private var todaysCount: Int {
        polaroidStore.todaysCaptureCount()
    }

    private var hasUnreleasedToday: Bool {
        !polaroidStore.todaysUnreleasedEntries().isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                topBar

                Divider()
                    .background(Color.white.opacity(0.3))

                captureSection

                if hasUnreleasedToday && todaysCount > 0 {
                    manualReleaseButton
                        .padding(.top, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [BabyTownTheme.accentDeep, BabyTownTheme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 20, y: -5)
            )
        }
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
        .onAppear { locationManager.requestPermissionAndStart() }
        .onDisappear { locationManager.stop() }
        .fullScreenCover(isPresented: $showCamera) {
            CustomCameraView(image: $capturedImage, canCapture: true)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                capturedImage = nil
                Task {
                    await handleCapturedPhoto(image)
                }
            }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Polaroids")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)

                Text("\(todaysCount) photo\(todaysCount == 1 ? "" : "s") today")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var captureSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)

                    Text("Capture a moment")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("Photos reveal at 9:00 PM PST")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.leading, 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Button {
                showCamera = true
            } label: {
                Text("Take Photo")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(.white)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                    )
            }
            .padding(.horizontal, 24)

            if showNotification {
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.white)
                        Text(notificationMessage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("Take another photo if you'd like")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.bottom, 24)
    }

    private var manualReleaseButton: some View {
        Button {
            showReleaseConfirmation = true
        } label: {
            Text("Add to Covela Now")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .strokeBorder(.white, lineWidth: 2)
                        .background(Capsule().fill(.white.opacity(0.15)))
                )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
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
}

#Preview {
    CameraCaptureView(
        polaroidStore: LocalPolaroidStore(),
        onPhotosReleased: { _ in }
    )
}
