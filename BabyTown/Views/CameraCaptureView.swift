import SwiftUI

struct CameraCaptureView: View {
    
    @ObservedObject var polaroidStore: LocalPolaroidStore
    @Environment(\.dismiss) private var dismiss
    var onPhotosReleased: () -> Void
    
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showNotification = false
    @State private var notificationMessage = ""
    
    private let dailyLimit = 5
    
    private var todaysCount: Int {
        polaroidStore.todaysCaptureCount()
    }
    
    private var canCapture: Bool {
        todaysCount < dailyLimit
    }
    
    private var hasUnreleasedToday: Bool {
        !polaroidStore.todaysUnreleasedEntries().isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                topBar
                
                if canCapture {
                    captureSection
                } else {
                    limitReachedSection
                }
                
                if hasUnreleasedToday && todaysCount > 0 {
                    manualReleaseButton
                        .padding(.top, 16)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(BabyTownTheme.background)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
            )
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showCamera) {
            CameraPickerView(image: $capturedImage)
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
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily Polaroids")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                
                Text("\(todaysCount) of \(dailyLimit) for today")
                    .font(.system(size: 12))
                    .foregroundStyle(BabyTownTheme.textSecondary)
            }
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("Close")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(BabyTownTheme.accent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
    
    private var captureSection: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [BabyTownTheme.accent, BabyTownTheme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Capture a moment")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                    
                    Text("Photos reveal at 9:00 PM • Resets at 5:00 AM")
                        .font(.system(size: 13))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            
            Button {
                showCamera = true
            } label: {
                Text("Take Photo")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(BabyTownTheme.accentGradient)
                            .shadow(color: BabyTownTheme.buttonShadow, radius: 8, y: 3)
                    )
            }
            .padding(.horizontal, 24)
            
            if showNotification {
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(BabyTownTheme.accent)
                        Text(notificationMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(BabyTownTheme.textPrimary)
                    }
                    Text("Take another photo if you'd like")
                        .font(.system(size: 11))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(BabyTownTheme.accentSoft)
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.bottom, 20)
    }
    
    private var limitReachedSection: some View {
        HStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("That's 5 for today")
                    .font(.system(size: 18, weight: .medium, design: .serif))
                    .foregroundStyle(BabyTownTheme.textPrimary)
                
                Text("See you at 9:00 PM when your photos reveal\nLimit resets at 5:00 AM")
                    .font(.system(size: 13))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    private var manualReleaseButton: some View {
        Button {
            releaseNow()
        } label: {
            Text("Add to Baby Town Now")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BabyTownTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .strokeBorder(BabyTownTheme.accent, lineWidth: 1.5)
                        .background(Capsule().fill(BabyTownTheme.accentSoft))
                )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    
    private func handleCapturedPhoto(_ image: UIImage) {
        guard polaroidStore.savePhoto(image) != nil else { return }
        
        let _ = dailyLimit - todaysCount
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
        polaroidStore.releaseEntries(toRelease)
        onPhotosReleased()
        dismiss()
    }
}

#Preview {
    CameraCaptureView(
        polaroidStore: LocalPolaroidStore(),
        onPhotosReleased: {}
    )
}
