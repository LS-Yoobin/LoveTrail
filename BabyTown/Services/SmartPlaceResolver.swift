import Foundation
import CoreLocation
import MapKit
import Photos
import ImageIO

/// Smart place name resolver with a multi-stage pipeline:
///   1. Cached known places (in-memory grid cache)
///   2. User saved places (Home, Work, Favorites within 80m)
///   3. MKLocalSearch POI lookup (within 150m radius)
///   4. CLGeocoder reverse geocode fallback
///   5. Final fallback: "Unknown Place"
///
/// Supports resolution from PHAsset, raw image Data, or CLLocation.
/// All results are cached for fast repeat lookups.
final class SmartPlaceResolver {

    static let shared = SmartPlaceResolver()

    private let cache = PlaceCacheStore.shared
    private let geocoder = CLGeocoder()

    /// MKLocalSearch radius in meters
    private let poiSearchRadius: CLLocationDistance = 150

    private init() {}

    // MARK: - Public API

    /// Resolve from a PHAsset's embedded GPS location.
    func resolve(from asset: PHAsset?) async -> String? {
        guard let asset, let location = asset.location else {
            return nil
        }
        return await resolvePlaceName(for: location)
    }

    /// Resolve from raw image Data (EXIF GPS).
    func resolve(from imageData: Data?) async -> String? {
        guard let data = imageData,
              let location = Self.extractLocation(from: data) else {
            return nil
        }
        return await resolvePlaceName(for: location)
    }

    /// Resolve from an explicit CLLocation.
    func resolve(from location: CLLocation?) async -> String? {
        guard let location else { return nil }
        return await resolvePlaceName(for: location)
    }

    // MARK: - Pipeline

    /// Main resolution pipeline. Returns a human-readable place name.
    func resolvePlaceName(for location: CLLocation) async -> String {

        // Stage A: Check in-memory grid cache
        if let cached = cache.cachedName(for: location) {
            return cached
        }

        // Stage B: Check user saved places (within 80m)
        if let saved = cache.matchSavedPlace(for: location) {
            let name = saved.name
            cache.store(name: name, for: location)
            return name
        }

        // Stage C: MKLocalSearch POI lookup (within 150m)
        if let poi = await searchPOI(near: location) {
            cache.store(name: poi, for: location)
            return poi
        }

        // Stage D: CLGeocoder reverse geocode
        if let geocoded = await reverseGeocode(location) {
            cache.store(name: geocoded, for: location)
            return geocoded
        }

        // Stage E: Final fallback
        let fallback = "Unknown Place"
        cache.store(name: fallback, for: location)
        return fallback
    }

    // MARK: - Stage C: MKLocalSearch

    private func searchPOI(near location: CLLocation) async -> String? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "point of interest"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: poiSearchRadius * 2,
            longitudinalMeters: poiSearchRadius * 2
        )
        request.resultTypes = .pointOfInterest

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            // Find the closest POI within the radius
            var best: (name: String, distance: CLLocationDistance)?

            for item in response.mapItems {
                guard let name = item.name, !name.isEmpty else { continue }

                let itemLocation = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
                let distance = location.distance(from: itemLocation)

                if distance <= poiSearchRadius {
                    if best == nil || distance < best!.distance {
                        best = (name, distance)
                    }
                }
            }

            return best?.name
        } catch {
            print("[SmartPlaceResolver] MKLocalSearch failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Stage D: CLGeocoder

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        geocoder.cancelGeocode()

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            return Self.buildDisplayName(from: placemark)
        } catch {
            print("[SmartPlaceResolver] Reverse geocode failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Display Name Builder

    static func buildDisplayName(from placemark: CLPlacemark) -> String? {
        // 1. Recognizable place name (e.g. "Blue Bottle Coffee")
        if let name = placemark.name,
           name != placemark.locality,
           name != placemark.administrativeArea {
            return name
        }

        // 2. City + State
        if let city = placemark.locality {
            if let state = placemark.administrativeArea {
                return "\(city), \(state)"
            }
            return city
        }

        // 3. Neighborhood
        if let subLocality = placemark.subLocality {
            return subLocality
        }

        // 4. State alone
        if let state = placemark.administrativeArea {
            return state
        }

        // 5. Country
        if let country = placemark.country {
            return country
        }

        return nil
    }

    // MARK: - EXIF GPS Extraction

    static func extractLocation(from imageData: Data) -> CLLocation? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] else {
            return nil
        }

        guard let latitude = gps[kCGImagePropertyGPSLatitude] as? Double,
              let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String,
              let longitude = gps[kCGImagePropertyGPSLongitude] as? Double,
              let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String else {
            return nil
        }

        let lat = latRef == "S" ? -latitude : latitude
        let lon = lonRef == "W" ? -longitude : longitude

        return CLLocation(latitude: lat, longitude: lon)
    }
}
