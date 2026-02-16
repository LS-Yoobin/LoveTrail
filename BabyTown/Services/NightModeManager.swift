import SwiftUI
import Combine

/// Manages night mode state based on local time
/// Automatically switches to night mode between 9PM and 6AM
class NightModeManager: ObservableObject {
    
    @Published var isNightMode: Bool = false
    
    private var timer: Timer?
    private let calendar = Calendar.current
    
    init() {
        evaluateNightMode()
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    /// Starts a timer that re-evaluates night mode every 60 seconds
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.evaluateNightMode()
        }
    }
    
    /// Evaluates whether it's currently night time (9PM - 6AM) in LA timezone
    private func evaluateNightMode() {
        guard let laTimeZone = TimeZone(identifier: "America/Los_Angeles") else { return }
        
        var laCalendar = Calendar.current
        laCalendar.timeZone = laTimeZone
        
        let now = Date()
        let hour = laCalendar.component(.hour, from: now)
        
        // Night mode is active from 9PM (21:00) to 6AM (06:00) LA time
        let shouldBeNightMode = hour >= 21 || hour < 6
        
        if isNightMode != shouldBeNightMode {
            withAnimation(.easeInOut(duration: 0.8)) {
                isNightMode = shouldBeNightMode
            }
        }
    }
}
