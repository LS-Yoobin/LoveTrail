import SwiftUI
import Combine

struct ProcessingMemoryCard: View {
    let memory: ProcessingMemory
    var pendingCount: Int = 1
    let image: UIImage?
    var onUnlock: (() -> Void)? = nil
    @State private var currentTime = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 240)
                        .clipped()
                        .blur(radius: 20)
                        .overlay(
                            Rectangle()
                                .fill(.black.opacity(0.4))
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 240)
                }
                
                VStack(spacing: 16) {
                    processingAnimation
                    
                    VStack(spacing: 8) {
                        Text(memory.timeUntilUnlock())
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        
                        Text(processingStatusText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text(formatCaptureTimestamp(memory.date))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                Text(darkroomFooterText)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineSpacing(2)
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            BabyTownTheme.accentDeep,
                            BabyTownTheme.accentDeep
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
        .onReceive(timer) { _ in
            currentTime = Date()
            if memory.unlockTime <= Date() {
                onUnlock?()
            }
        }
    }
    
    private var processingStatusText: String {
        if pendingCount > 1 {
            return "Processing \(pendingCount) memories..."
        }
        return "Processing your memory..."
    }

    private var darkroomFooterText: String {
        if pendingCount > 1 {
            return "Your captures are in the darkroom — curtain up at 9 PM PST."
        }
        return "Still in the darkroom — curtain up at 9 PM PST."
    }

    private var processingAnimation: some View {
        ZStack {
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 60, height: 60)
            
            RotatingDotsView()
                .frame(width: 60, height: 60)
        }
    }
    
    private func formatCaptureTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy • h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: date) + " PST"
    }
}

struct RotatingDotsView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<8) { index in
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                    .offset(y: -20)
                    .rotationEffect(.degrees(Double(index) * 45))
                    .opacity(dotOpacity(for: index))
            }
        }
        .rotationEffect(.degrees(rotation))
        .onAppear {
            withAnimation(
                .linear(duration: 1.2)
                .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
        }
    }
    
    private func dotOpacity(for index: Int) -> Double {
        let phase = (rotation + Double(index) * 45).truncatingRemainder(dividingBy: 360)
        return 0.3 + (phase / 360) * 0.7
    }
}
