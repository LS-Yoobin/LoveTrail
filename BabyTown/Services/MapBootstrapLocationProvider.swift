import CoreLocation
import Foundation

/// One-shot device location for memory location map bootstrap (does not run continuous updates).
enum MapBootstrapLocationProvider {
    private static let fetchTimeout: TimeInterval = 2.5

    static func currentCoordinate() async -> CLLocationCoordinate2D? {
        await MapBootstrapLocationSession().fetchCoordinate(timeout: fetchTimeout)
    }
}

@MainActor
private final class MapBootstrapLocationSession: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private var timeoutTask: Task<Void, Never>?

    func fetchCoordinate(timeout: TimeInterval) async -> CLLocationCoordinate2D? {
        manager.delegate = self

        switch manager.authorizationStatus {
        case .restricted, .denied:
            return nil
        case .notDetermined:
            return await waitForLocation(afterRequestingAuthorization: true, timeout: timeout)
        case .authorizedAlways, .authorizedWhenInUse:
            return await waitForLocation(afterRequestingAuthorization: false, timeout: timeout)
        @unknown default:
            return nil
        }
    }

    private func waitForLocation(afterRequestingAuthorization: Bool, timeout: TimeInterval) async -> CLLocationCoordinate2D? {
        if !afterRequestingAuthorization, let cached = manager.location {
            return cached.coordinate
        }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            if afterRequestingAuthorization {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
            scheduleTimeout(timeout)
        }
    }

    private func scheduleTimeout(_ seconds: TimeInterval) {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finish(with: nil)
        }
    }

    private func finish(with coordinate: CLLocationCoordinate2D?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(returning: coordinate)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if let cached = manager.location {
                finish(with: cached.coordinate)
            } else {
                manager.requestLocation()
            }
        case .denied, .restricted:
            finish(with: nil)
        case .notDetermined:
            break
        @unknown default:
            finish(with: nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        finish(with: location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: manager.location?.coordinate)
    }
}

/// Permission-free map center when device location is unavailable.
enum MapRegionalDefault {
    static let spanMeters: CLLocationDistance = 40_000

    static func coordinate() -> CLLocationCoordinate2D {
        let code = Locale.current.region?.identifier ?? "US"
        return centroids[code] ?? centroids["US"]!
    }

    private static let centroids: [String: CLLocationCoordinate2D] = [
        "US": .init(latitude: 39.8283, longitude: -98.5795),
        "CA": .init(latitude: 56.1304, longitude: -106.3468),
        "GB": .init(latitude: 55.3781, longitude: -3.4360),
        "AU": .init(latitude: -25.2744, longitude: 133.7751),
        "DE": .init(latitude: 51.1657, longitude: 10.4515),
        "FR": .init(latitude: 46.2276, longitude: 2.2137),
        "JP": .init(latitude: 36.2048, longitude: 138.2529),
        "KR": .init(latitude: 35.9078, longitude: 127.7669),
        "IN": .init(latitude: 20.5937, longitude: 78.9629),
        "BR": .init(latitude: -14.2350, longitude: -51.9253),
        "MX": .init(latitude: 23.6345, longitude: -102.5528),
    ]
}

enum MapBootstrapResult {
    case memoryOrPhoto(CLLocationCoordinate2D, prefillCoordinates: Bool)
    case viewportDevice(CLLocationCoordinate2D)
    case viewportRegional(CLLocationCoordinate2D)

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .memoryOrPhoto(let c, _), .viewportDevice(let c), .viewportRegional(let c):
            return c
        }
    }

    var spanMeters: CLLocationDistance {
        switch self {
        case .memoryOrPhoto:
            return 350
        case .viewportDevice:
            return 8_000
        case .viewportRegional:
            return MapRegionalDefault.spanMeters
        }
    }

    var showsUserLocation: Bool {
        if case .viewportDevice = self { return true }
        return false
    }

    var showsPin: Bool {
        switch self {
        case .memoryOrPhoto:
            return true
        case .viewportDevice, .viewportRegional:
            return false
        }
    }

    var viewportHint: String? {
        switch self {
        case .memoryOrPhoto:
            return nil
        case .viewportDevice:
            return "Centered near you — search or tap the map to choose a place"
        case .viewportRegional:
            return "Search or pan to choose a place"
        }
    }
}
