import SwiftUI

struct HeartTrailBackground: View {

    var sectionCount: Int

    @State private var trailOpacity: Double = 0

    private let amplitude: CGFloat = 100
    private let frequency: CGFloat = 150
    private let heartSpacing: CGFloat = 60

    var body: some View {
        GeometryReader { geo in
            ZStack {
                HeartTrailPath(amplitude: amplitude, frequency: frequency)
                    .stroke(
                        BabyTownTheme.accent.opacity(0.15),
                        style: StrokeStyle(
                            lineWidth: 5,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                
                heartFootprints(in: geo.size)
            }
        }
        .opacity(trailOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.9).delay(0.3)) {
                trailOpacity = 1
            }
        }
        .allowsHitTesting(false)
    }
    
    private func heartFootprints(in size: CGSize) -> some View {
        let centerX = size.width / 2
        let height = size.height
        let count = Int(height / heartSpacing)
        
        return ForEach(0..<count, id: \.self) { i in
            let t = CGFloat(i) / CGFloat(count)
            let y = t * height
            let x = centerX + amplitude * sin(t * .pi * 4)
            let rotation = cos(t * .pi * 4) * 15
            let size: CGFloat = i % 2 == 0 ? 20 : 15
            let opacity = i % 3 == 0 ? 0.2 : 0.15
            
            Image(systemName: "heart.fill")
                .font(.system(size: size))
                .foregroundStyle(BabyTownTheme.accent.opacity(opacity))
                .rotationEffect(.degrees(rotation))
                .position(x: x, y: y)
        }
    }
}

#Preview {
    HeartTrailBackground(sectionCount: 3)
        .frame(height: 600)
        .background(Color.white)
}
