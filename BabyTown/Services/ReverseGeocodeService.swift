import CoreLocation
import Foundation

/// Serializes CLGeocoder requests with throttling and retries so bulk scans
/// (and backfills) stay within Apple's reverse-geocoding limits.
actor ReverseGeocodeService {

    static let shared = ReverseGeocodeService()

    private let geocoder = CLGeocoder()
    private var lastRequestTime = Date.distantPast
    private var placemarkCache: [String: CLPlacemark] = [:]

    /// Minimum spacing between requests (~50/minute ceiling).
    private let minInterval: TimeInterval = 1.2

    private init() {}

    func placemark(for location: CLLocation) async -> CLPlacemark? {
        guard Self.isValidCoordinate(location.coordinate) else { return nil }

        let key = Self.coordinateCacheKey(for: location.coordinate)
        if let cached = placemarkCache[key] {
            return cached
        }

        await throttle()

        for attempt in 0..<3 {
            do {
                geocoder.cancelGeocode()
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    placemarkCache[key] = placemark
                    let placeName = PlacemarkDisplayNameBuilder.build(from: placemark)
                    GeocodeCacheStore.shared.store(
                        placeName: placeName,
                        country: placemark.country,
                        for: location.coordinate
                    )
                    return placemark
                }
                return nil
            } catch {
                let shouldRetry = attempt < 2 && Self.shouldRetry(error)
                if shouldRetry {
                    await throttle(forceDelay: minInterval * Double(attempt + 2))
                    continue
                }
                print("[ReverseGeocodeService] Failed: \(error.localizedDescription)")
                return nil
            }
        }

        return nil
    }

    private func throttle(forceDelay: TimeInterval? = nil) async {
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        let delay = forceDelay ?? max(0, minInterval - elapsed)
        if delay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        lastRequestTime = Date()
    }

    static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        CLLocationCoordinate2DIsValid(coordinate)
            && abs(coordinate.latitude) <= 90
            && abs(coordinate.longitude) <= 180
            && !(coordinate.latitude == 0 && coordinate.longitude == 0)
    }

    private static func shouldRetry(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == kCLErrorDomain {
            switch CLError.Code(rawValue: nsError.code) {
            case .network, .locationUnknown:
                return true
            default:
                return false
            }
        }
        // GEOErrorDomain code 8 = throttled
        if nsError.domain == "GEOErrorDomain", nsError.code == 8 {
            return true
        }
        return false
    }

    static func coordinateCacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        let lat = (coordinate.latitude * 1000).rounded() / 1000
        let lon = (coordinate.longitude * 1000).rounded() / 1000
        return "\(lat),\(lon)"
    }
}

enum PlacemarkDisplayNameBuilder {

    static func build(from placemark: CLPlacemark) -> String? {
        if let area = placemark.areasOfInterest?.first, !area.isEmpty {
            return area
        }

        if let name = placemark.name, !name.isEmpty, !isGenericPlacemarkName(name, placemark: placemark) {
            return name
        }

        if let thoroughfare = placemark.thoroughfare {
            if let number = placemark.subThoroughfare {
                return "\(number) \(thoroughfare)"
            }
            return thoroughfare
        }

        if let city = placemark.locality {
            if let state = placemark.administrativeArea {
                return "\(city), \(state)"
            }
            return city
        }

        if let subLocality = placemark.subLocality {
            return subLocality
        }

        if let subAdmin = placemark.subAdministrativeArea {
            return subAdmin
        }

        if let state = placemark.administrativeArea {
            return state
        }

        if let water = placemark.inlandWater ?? placemark.ocean {
            return water
        }

        if let country = placemark.country {
            return country
        }

        return nil
    }

    private static func isGenericPlacemarkName(_ name: String, placemark: CLPlacemark) -> Bool {
        let genericValues = [
            placemark.locality,
            placemark.administrativeArea,
            placemark.subAdministrativeArea,
            placemark.country,
            placemark.postalCode
        ]
        return genericValues.compactMap { $0 }.contains(name)
    }
}
