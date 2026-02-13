import SwiftUI

struct PolaroidCameraView: View {
    
    @ObservedObject var polaroidStore: LocalPolaroidStore
    @Environment(\.dismiss) private var dismiss
    var onPhotosReleased: ([PolaroidEntry]) -> Void
    
    @State private var capturedImage: UIImage?
    @State private var showNotification = false
    @State private var notificationMessage = ""
    @State private var showReleaseConfirmation = false
    
    @AppStorage("currentCatVariantIndex") private var currentCatVariantIndex = 1
    
    private let dailyLimit = 5
    
    private var todaysCount: Int {
        polaroidStore.todaysCaptureCount()
    }
    
    private var hasUnreleasedToday: Bool {
        !polaroidStore.todaysUnreleasedEntries().isEmpty
    }
    
    var body: some View {
        ZStack {
            CustomCameraView(image: $capturedImage, canCapture: polaroidStore.canCapturePhoto())
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
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                handleCapturedPhoto(image)
                capturedImage = nil
            }
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
            
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("\(todaysCount) of \(dailyLimit)")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.26, blue: 0.35), Color(red: 0.88, green: 0.22, blue: 0.32)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
            )
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
            
            if todaysCount < dailyLimit {
                Text("Take another photo if you'd like")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
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
    
    private func handleCapturedPhoto(_ image: UIImage) {
        guard polaroidStore.canCapturePhoto() else {
            notificationMessage = "Done for today! New photos at midnight"
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showNotification = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    showNotification = false
                }
            }
            return
        }

        guard polaroidStore.savePhoto(image) != nil else { return }

        let remaining = dailyLimit - todaysCount

        if remaining > 0 {
            notificationMessage = "Photo saved! \(remaining) left for today"
        } else {
            notificationMessage = "That's 5 for today! See you at 9 PM"
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showNotification = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
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
