import SwiftUI

struct PlannerBackgroundView: View {
    private let pinPositions: [(CGFloat, CGFloat)] = [
        (0.15, 0.20), (0.75, 0.10), (0.50, 0.45),
        (0.90, 0.60), (0.30, 0.75), (0.65, 0.85),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                BabyTownTheme.backgroundGradient

                Canvas { ctx, size in
                    // Grid lines every 60pt
                    var x: CGFloat = 0
                    while x <= size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        ctx.stroke(path, with: .color(BabyTownTheme.accent.opacity(0.03)), lineWidth: 0.5)
                        x += 60
                    }
                    var y: CGFloat = 0
                    while y <= size.height {
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(path, with: .color(BabyTownTheme.accent.opacity(0.03)), lineWidth: 0.5)
                        y += 60
                    }

                    // Diagonal dashed routes
                    let diagonals: [(CGPoint, CGPoint)] = [
                        (CGPoint(x: 0, y: size.height * 0.20), CGPoint(x: size.width, y: size.height * 0.70)),
                        (CGPoint(x: 0, y: size.height * 0.50), CGPoint(x: size.width, y: size.height * 0.90)),
                        (CGPoint(x: size.width * 0.10, y: 0), CGPoint(x: size.width * 0.80, y: size.height)),
                        (CGPoint(x: size.width * 0.60, y: 0), CGPoint(x: size.width, y: size.height * 0.50)),
                    ]
                    for (from, to) in diagonals {
                        var path = Path()
                        path.move(to: from)
                        path.addLine(to: to)
                        ctx.stroke(
                            path,
                            with: .color(BabyTownTheme.accent.opacity(0.05)),
                            style: StrokeStyle(lineWidth: 1, dash: [6, 8])
                        )
                    }
                }

                ForEach(pinPositions.indices, id: \.self) { i in
                    let (fx, fy) = pinPositions[i]
                    Image(systemName: "mappin")
                        .font(.system(size: 14))
                        .foregroundStyle(BabyTownTheme.accent.opacity(0.06))
                        .position(x: geo.size.width * fx, y: geo.size.height * fy)
                }

                Image(systemName: "location.north.line")
                    .font(.system(size: 72))
                    .foregroundStyle(BabyTownTheme.accent.opacity(0.05))
                    .position(x: geo.size.width * 0.20, y: geo.size.height * 0.80)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    PlannerBackgroundView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
}
