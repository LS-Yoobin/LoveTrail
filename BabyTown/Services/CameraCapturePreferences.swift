import Foundation

enum CameraCaptureMode: String, CaseIterable, Identifiable {
    case photo
    case vibe
    case reel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .photo: return "Photo"
        case .vibe: return "Vibe"
        case .reel: return "Reel"
        }
    }
}

enum ReelPreferences {
    static let userDefaultsKey = "babytown.camera.reelMaxDurationSeconds"
    static let defaultDurationSeconds: TimeInterval = 5
    static let choices: [TimeInterval] = [5, 10, 15, 30]

    static var maxDurationSeconds: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: userDefaultsKey)
        if stored > 0, choices.contains(stored) { return stored }
        return defaultDurationSeconds
    }

    static func label(for seconds: TimeInterval) -> String {
        "\(Int(seconds)) sec"
    }
}

enum ReelStopMode: String, CaseIterable {
    case auto
    case manual

    static let userDefaultsKey = "babytown.camera.reelStopMode"

    static var current: ReelStopMode {
        let raw = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        return ReelStopMode(rawValue: raw) ?? .auto
    }

    var shortLabel: String {
        switch self {
        case .auto: return "Auto"
        case .manual: return "Manual"
        }
    }

    var label: String {
        switch self {
        case .auto: return "Auto Stop"
        case .manual: return "Manual Stop"
        }
    }
}
