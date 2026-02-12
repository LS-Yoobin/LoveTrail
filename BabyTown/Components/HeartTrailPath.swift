import SwiftUI

struct HeartTrailPath: Shape {
    
    let amplitude: CGFloat
    let frequency: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let centerX = rect.midX
        let startY = rect.minY
        let endY = rect.maxY
        let height = endY - startY
        
        path.move(to: CGPoint(x: centerX, y: startY))
        
        let segments = Int(height / frequency)
        
        for i in 0..<segments {
            let t = CGFloat(i) / CGFloat(segments)
            let nextT = CGFloat(i + 1) / CGFloat(segments)
            
            let currentY = startY + t * height
            let nextY = startY + nextT * height
            
            let _ = centerX + amplitude * sin(t * .pi * 4)
            let nextX = centerX + amplitude * sin(nextT * .pi * 4)
            
            let controlY1 = currentY + (nextY - currentY) * 0.33
            let controlY2 = currentY + (nextY - currentY) * 0.67
            
            let controlX1 = centerX + amplitude * sin((t + (nextT - t) * 0.33) * .pi * 4)
            let controlX2 = centerX + amplitude * sin((t + (nextT - t) * 0.67) * .pi * 4)
            
            path.addCurve(
                to: CGPoint(x: nextX, y: nextY),
                control1: CGPoint(x: controlX1, y: controlY1),
                control2: CGPoint(x: controlX2, y: controlY2)
            )
        }
        
        return path
    }
}
