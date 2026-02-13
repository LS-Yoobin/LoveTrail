import SwiftUI

struct TimeUntilUnlockView: View {
    let unlockTime: Date
    
    @State private var timeRemaining: String = ""
    @State private var timer: Timer?
    
    var body: some View {
        Text(timeRemaining)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .onAppear {
                updateTimeRemaining()
                timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                    updateTimeRemaining()
                }
            }
            .onDisappear {
                timer?.invalidate()
            }
    }
    
    private func updateTimeRemaining() {
        let now = Date()
        let timeInterval = unlockTime.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            timeRemaining = "Available Now"
            timer?.invalidate()
        } else {
            let hours = Int(timeInterval) / 3600
            if hours > 0 {
                let hourText = hours == 1 ? "Hour" : "Hours"
                timeRemaining = "Available in \(hours) \(hourText)"
            } else {
                let minutes = max(1, Int(timeInterval) / 60)
                let minuteText = minutes == 1 ? "Minute" : "Minutes"
                timeRemaining = "Available in \(minutes) \(minuteText)"
            }
        }
    }
}
