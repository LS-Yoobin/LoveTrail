import SwiftUI

/// Passive mood icon rain for the secret garden. Sits above the living garden
/// backdrop and below interactive scroll content.
struct GardenMoodRainOverlay: View {
    let mood: ProfileNoteMood

    private struct Particle: Identifiable {
        let id: Int
        let xFraction: CGFloat
        let speed: CGFloat
        let size: CGFloat
        let phase: CGFloat
        let swayAmplitude: CGFloat
        let swayFrequency: CGFloat
        let opacity: CGFloat
    }

    private static let particles: [Particle] = (0..<32).map { index in
        let seed = CGFloat(index)
        let isLarge = index.isMultiple(of: 4) || index.isMultiple(of: 7)
        return Particle(
            id: index,
            xFraction: seededValue(seed * 1.7, min: 0.04, max: 0.96),
            speed: seededValue(seed * 2.3, min: 28, max: 72),
            size: isLarge
                ? seededValue(seed * 3.1, min: 26, max: 38)
                : seededValue(seed * 3.1, min: 11, max: 22),
            phase: seededValue(seed * 4.9, min: 0, max: 1),
            swayAmplitude: seededValue(seed * 5.7, min: 4, max: 14),
            swayFrequency: seededValue(seed * 6.3, min: 0.6, max: 1.4),
            opacity: seededValue(seed * 7.1, min: isLarge ? 0.28 : 0.22, max: isLarge ? 0.55 : 0.48)
        )
    }

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let width = geo.size.width

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    mood.tintColor.opacity(0.06)
                        .ignoresSafeArea()

                    ForEach(Self.particles) { particle in
                        let travel = height + 80
                        let y = ((time * Double(particle.speed) + Double(particle.phase) * Double(travel))
                            .truncatingRemainder(dividingBy: Double(travel))) - 40
                        let sway = sin(time * particle.swayFrequency + Double(particle.id)) * particle.swayAmplitude
                        let x = particle.xFraction * width + sway

                        Image(systemName: mood.iconName)
                            .font(.system(size: particle.size, weight: .semibold))
                            .foregroundStyle(mood.tintColor.opacity(particle.opacity))
                            .rotationEffect(.degrees(sin(time * 0.5 + Double(particle.id)) * 12))
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func seededValue(_ seed: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        let normalized = abs(sin(seed * 12.9898 + 78.233) * 43_758.5453).truncatingRemainder(dividingBy: 1)
        return min + normalized * (max - min)
    }
}
