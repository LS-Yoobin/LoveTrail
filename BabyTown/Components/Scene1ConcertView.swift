import SwiftUI

struct Scene1ConcertView: View {
    @Binding var isInteractionComplete: Bool
    @State private var showSparkles = false
    @State private var sparkles: [SparkleParticle] = []
    @State private var raveLights: [RaveLight] = []
    @State private var musicalNotes: [MusicalNote] = []
    @State private var showRaveLights = false
    @State private var floatingOffset: CGFloat = 0
    @State private var animationTriggered = false
    
    struct SparkleParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var opacity: Double = 1.0
        var scale: CGFloat = 1.0
        var color: Color = .yellow
    }
    
    struct RaveLight: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var color: Color
        var secondaryColor: Color
        var opacity: Double = 0.0
        var scale: CGFloat = 0.5
        var rotation: Double = 0
    }
    
    struct MusicalNote: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var opacity: Double = 1.0
        var scale: CGFloat = 1.0
        var rotation: Double = 0
        var symbol: String
        var color: Color = .white
    }
    
    var body: some View {
        ZStack {
            if showRaveLights {
                GeometryReader { geometry in
                    ZStack {
                        ForEach(raveLights) { light in
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [light.color, light.secondaryColor.opacity(0.6)],
                                            center: .center,
                                            startRadius: 20,
                                            endRadius: 75
                                        )
                                    )
                                    .frame(width: 150, height: 150)
                                    .blur(radius: 35)
                                    .opacity(light.opacity)
                                    .scaleEffect(light.scale)
                                
                                Circle()
                                    .fill(light.color)
                                    .frame(width: 80, height: 80)
                                    .blur(radius: 20)
                                    .opacity(light.opacity * 1.2)
                                    .scaleEffect(light.scale * 0.6)
                            }
                            .rotationEffect(.degrees(light.rotation))
                            .position(x: light.x, y: light.y)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                ZStack {
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.purple.opacity(0.4),
                                    Color.pink.opacity(0.3),
                                    Color.blue.opacity(0.3),
                                    Color.cyan.opacity(0.2)
                                ],
                                center: .center,
                                startRadius: 30,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.purple.opacity(0.6), .pink.opacity(0.6), .cyan.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                        )
                    
                    Image(systemName: "music.note.list")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    ForEach(sparkles) { sparkle in
                        ZStack {
                            Circle()
                                .fill(sparkle.color)
                                .frame(width: 8, height: 8)
                                .blur(radius: 2)
                            
                            Circle()
                                .fill(.white)
                                .frame(width: 4, height: 4)
                        }
                        .opacity(sparkle.opacity)
                        .scaleEffect(sparkle.scale)
                        .position(x: sparkle.x, y: sparkle.y)
                    }
                }
                .frame(height: 280)
            }
            
            if showRaveLights {
                GeometryReader { geometry in
                    ForEach(musicalNotes) { note in
                        Text(note.symbol)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [note.color, note.color.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: note.color.opacity(0.8), radius: 8, x: 0, y: 0)
                            .opacity(note.opacity)
                            .scaleEffect(note.scale)
                            .rotationEffect(.degrees(note.rotation))
                            .position(x: note.x, y: note.y)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            startFloatingAnimation()
        }
        .onChange(of: isInteractionComplete) { _, newValue in
            if newValue && !animationTriggered {
                animationTriggered = true
                triggerSparkles()
            }
        }
    }
    
    private func startFloatingAnimation() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            floatingOffset = -8
        }
    }
    
    private func triggerSparkles() {
        let centerX: CGFloat = 200
        let centerY: CGFloat = 140
        
        let sparkleColors: [Color] = [
            .yellow, .orange, .pink, .cyan, .white, .purple, .mint, .indigo
        ]
        
        for _ in 0..<50 {
            let angle = Double.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 50...150)
            let x = centerX + cos(angle) * distance
            let y = centerY + sin(angle) * distance
            let color = sparkleColors.randomElement() ?? .yellow
            
            let sparkle = SparkleParticle(x: centerX, y: centerY, color: color)
            sparkles.append(sparkle)
            
            withAnimation(.easeOut(duration: 1.0)) {
                if let index = sparkles.firstIndex(where: { $0.id == sparkle.id }) {
                    sparkles[index].x = x
                    sparkles[index].y = y
                    sparkles[index].opacity = 0
                    sparkles[index].scale = 1.5
                }
            }
        }
        
        triggerRaveLights()
        triggerMusicalNotes()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            sparkles.removeAll()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation(.easeOut(duration: 1.0)) {
                showRaveLights = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                raveLights.removeAll()
                musicalNotes.removeAll()
            }
        }
    }
    
    private func triggerRaveLights() {
        showRaveLights = true
        
        let colors: [Color] = [
            .purple, .pink, .blue, .cyan, .mint, .teal, .indigo,
            .green, .yellow, .orange, .red, Color(red: 1.0, green: 0.0, blue: 0.5),
            Color(red: 0.5, green: 0.0, blue: 1.0), Color(red: 0.0, green: 1.0, blue: 0.5),
            Color(red: 1.0, green: 0.3, blue: 0.8), Color(red: 0.3, green: 0.8, blue: 1.0)
        ]
        
        for i in 0..<45 {
            let x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
            let y = CGFloat.random(in: 0...UIScreen.main.bounds.height)
            let color = colors.randomElement() ?? .purple
            let secondaryColor = colors.randomElement() ?? .pink
            
            var light = RaveLight(x: x, y: y, color: color, secondaryColor: secondaryColor)
            raveLights.append(light)
            
            let delay = Double(i) * 0.03
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(
                    .easeInOut(duration: 0.25)
                    .repeatCount(15, autoreverses: true)
                ) {
                    if let index = raveLights.firstIndex(where: { $0.id == light.id }) {
                        raveLights[index].opacity = Double.random(in: 0.6...0.9)
                        raveLights[index].scale = CGFloat.random(in: 1.2...3.0)
                    }
                }
                
                withAnimation(
                    .linear(duration: 3.5)
                    .repeatCount(1, autoreverses: false)
                ) {
                    if let index = raveLights.firstIndex(where: { $0.id == light.id }) {
                        raveLights[index].rotation = 360
                    }
                }
            }
        }
    }
    
    private func triggerMusicalNotes() {
        let noteSymbols = ["♪", "♫", "♬", "♩", "♭", "♮", "♯", "𝄞"]
        let noteColors: [Color] = [
            .purple, .pink, .cyan, .mint, .yellow, .orange, .indigo, .teal,
            Color(red: 1.0, green: 0.4, blue: 0.8), Color(red: 0.4, green: 0.8, blue: 1.0)
        ]
        
        for i in 0..<35 {
            let startX = CGFloat.random(in: 50...UIScreen.main.bounds.width - 50)
            let startY = UIScreen.main.bounds.height + 50
            let endY = CGFloat.random(in: -100...100)
            let symbol = noteSymbols.randomElement() ?? "♪"
            let color = noteColors.randomElement() ?? .white
            
            var note = MusicalNote(x: startX, y: startY, symbol: symbol, color: color)
            musicalNotes.append(note)
            
            let delay = Double(i) * 0.1
            let duration = Double.random(in: 2.0...3.5)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: duration)) {
                    if let index = musicalNotes.firstIndex(where: { $0.id == note.id }) {
                        musicalNotes[index].y = endY
                        musicalNotes[index].x = startX + CGFloat.random(in: -100...100)
                        musicalNotes[index].rotation = Double.random(in: -360...360)
                    }
                }
                
                withAnimation(.easeOut(duration: duration * 0.3).delay(duration * 0.7)) {
                    if let index = musicalNotes.firstIndex(where: { $0.id == note.id }) {
                        musicalNotes[index].opacity = 0
                    }
                }
            }
        }
    }
}

#Preview {
    Scene1ConcertView(isInteractionComplete: .constant(false))
        .padding()
        .background(StoryOnboardingTheme.backgroundBlush)
}
