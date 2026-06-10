import Foundation
import Photos
import CoreLocation
import ImageIO

final class LocationNameResolver {

    static let shared = LocationNameResolver()

    private var inFlightLookups: [String: Task<(name: String?, country: String?), Never>] = [:]

    private init() {}

    /// Resolve a place name from a PHAsset's embedded GPS location.
    func resolve(from asset: PHAsset?) async -> String? {
        guard let asset, let location = asset.location else {
            return nil
        }
        return await reverseGeocode(location)
    }

    /// Resolve a place name from raw image Data (EXIF GPS dictionary).
    func resolve(from imageData: Data?) async -> String? {
        guard let data = imageData, let location = Self.extractLocation(from: data) else {
            return nil
        }
        return await reverseGeocode(location)
    }

    /// Resolve a place name from an explicit CLLocation.
    func resolve(from location: CLLocation?) async -> String? {
        guard let location else { return nil }
        return await reverseGeocode(location)
    }
    
    /// Resolve a place name from coordinates (for Scan feature).
    /// Uses cache and coalesces concurrent lookups so each photo group triggers at most one geocode API call.
    func placeName(for coordinate: CLLocationCoordinate2D) async -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let name = await reverseGeocode(location) {
            return name
        }
        return "Unknown Area"
    }

    func reverseGeocode(_ coordinate: CLLocationCoordinate2D, useCache: Bool = true) async -> String {
        await placeName(for: coordinate)
    }
    
    /// Clear cached geocode results (memory and disk).
    func clearCache() {
        inFlightLookups.removeAll()
        GeocodeCacheStore.shared.clear()
    }

    /// Stable cache key for a coordinate (~100m grid). Used to dedupe geocode calls across photo groups.
    static func coordinateCacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        ReverseGeocodeService.coordinateCacheKey(for: coordinate)
    }


    // MARK: - Reverse Geocoding

    private func cacheKey(for location: CLLocation) -> String {
        Self.coordinateCacheKey(for: location.coordinate)
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        await resolveNameAndCountry(from: location).name
    }

    /// Resolve display name and country in a single geocode call (cached on disk).
    func resolveNameAndCountry(from location: CLLocation) async -> (name: String?, country: String?) {
        let key = cacheKey(for: location)

        if let cached = GeocodeCacheStore.shared.entry(forKey: key) {
            return (cached.placeName, cached.country)
        }

        if let existing = inFlightLookups[key] {
            return await existing.value
        }

        let task = Task<(name: String?, country: String?), Never> {
            guard ReverseGeocodeService.isValidCoordinate(location.coordinate) else {
                return (nil, nil)
            }

            let placemark = await ReverseGeocodeService.shared.placemark(for: location)
            let name = placemark.flatMap { PlacemarkDisplayNameBuilder.build(from: $0) }
            let country = placemark?.country
            return (name, country)
        }
        inFlightLookups[key] = task

        let result = await task.value
        inFlightLookups.removeValue(forKey: key)
        return result
    }

    /// Resolve just the country for a coordinate (cached, shares the geocode above).
    func country(from coordinate: CLLocationCoordinate2D) async -> String? {
        await resolveNameAndCountry(
            from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        ).country
    }

    static func buildDisplayName(from placemark: CLPlacemark) -> String? {
        PlacemarkDisplayNameBuilder.build(from: placemark)
    }

    // MARK: - EXIF GPS Extraction

    /// Parse GPS metadata from raw image data and return a CLLocation.
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
