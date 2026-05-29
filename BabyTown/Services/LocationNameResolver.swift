import Foundation
import Photos
import CoreLocation
import ImageIO

final class LocationNameResolver {

    /// Cache keyed by rounded coordinates (~100m precision) to avoid redundant geocode calls
    private var cache: [String: String?] = [:]
    private var countryCache: [String: String?] = [:]

    // MARK: - Public API

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
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D, useCache: Bool = true) async -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let name = await reverseGeocode(location) {
            return name
        }
        // Fallback to "Unknown Area" if geocoding fails
        return "Unknown Area"
    }
    
    /// Clear the geocoding cache.
    func clearCache() {
        cache.removeAll()
    }


    // MARK: - Reverse Geocoding

    private func cacheKey(for location: CLLocation) -> String {
        // Round to ~100m precision so nearby photos share the same result
        let lat = (location.coordinate.latitude * 1000).rounded() / 1000
        let lon = (location.coordinate.longitude * 1000).rounded() / 1000
        return "\(lat),\(lon)"
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        let key = cacheKey(for: location)

        // Return cached result if available
        if let cached = cache[key] {
            return cached
        }

        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            let name = placemarks.first.flatMap { Self.buildDisplayName(from: $0) }
            cache[key] = name
            return name
        } catch {
            print("[LocationNameResolver] Reverse geocode failed: \(error.localizedDescription)")
            cache[key] = nil
            return nil
        }
    }

    /// Resolve display name and country in a single geocode call (both cached).
    func resolveNameAndCountry(from location: CLLocation) async -> (name: String?, country: String?) {
        let key = cacheKey(for: location)
        if let name = cache[key], let country = countryCache[key] {
            return (name, country)
        }

        let geocoder = CLGeocoder()
        do {
            let placemark = try await geocoder.reverseGeocodeLocation(location).first
            let name = placemark.flatMap { Self.buildDisplayName(from: $0) }
            let country = placemark?.country
            cache[key] = name
            countryCache[key] = country
            return (name, country)
        } catch {
            cache[key] = nil
            countryCache[key] = nil
            return (nil, nil)
        }
    }

    /// Resolve just the country for a coordinate (cached, shares the geocode above).
    func country(from coordinate: CLLocationCoordinate2D) async -> String? {
        await resolveNameAndCountry(
            from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        ).country
    }

    // MARK: - Display Name Builder

    static func buildDisplayName(from placemark: CLPlacemark) -> String? {
        // 1. Prefer a recognizable place name (e.g. "Blue Bottle Coffee", street address)
        if let name = placemark.name,
           name != placemark.locality,
           name != placemark.administrativeArea {
            return name
        }

        // 2. City + State (e.g. "San Francisco, CA")
        if let city = placemark.locality {
            if let state = placemark.administrativeArea {
                return "\(city), \(state)"
            }
            return city
        }

        // 3. Sub-locality (neighborhood)
        if let subLocality = placemark.subLocality {
            return subLocality
        }

        // 4. State alone
        if let state = placemark.administrativeArea {
            return state
        }

        // 5. Country as last resort
        if let country = placemark.country {
            return country
        }

        return nil
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
