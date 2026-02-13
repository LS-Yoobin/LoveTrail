import SwiftUI
import Combine

struct ProcessingMemoryCard: View {
    let memory: ProcessingMemory
    let image: UIImage?
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
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
                        
                        Text("Processing your memory...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    Text(formatDate(memory.date))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                Text("Your 5th photo of the day is being processed. It will be revealed at 9:00 PM PST.")
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
                            Color(red: 0.95, green: 0.3, blue: 0.35),
                            Color(red: 0.88, green: 0.22, blue: 0.32)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        )
        .onReceive(timer) { _ in
            currentTime = Date()
        }
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: date)
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
