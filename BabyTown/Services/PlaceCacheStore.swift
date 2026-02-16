import Foundation
import CoreLocation

/// Thread-safe coordinate-based place name cache with saved places support.
/// Uses grid rounding (~30m precision) to deduplicate nearby lookups.
final class PlaceCacheStore {

    static let shared = PlaceCacheStore()

    // MARK: - Types

    struct SavedPlace: Codable, Identifiable {
        let id: UUID
        let label: String          // "Home", "Work", or custom
        let latitude: Double
        let longitude: Double
        let name: String           // Display name

        var location: CLLocation {
            CLLocation(latitude: latitude, longitude: longitude)
        }
    }

    // MARK: - Storage

    /// In-memory cache keyed by grid-rounded coordinate string
    private var cache: [String: String] = [:]
    private let lock = NSLock()

    /// Saved places persisted to disk
    private(set) var savedPlaces: [SavedPlace] = []
    private let savedPlacesKey = "BabyTown_SavedPlaces"

    /// Proximity threshold for saved places (meters)
    private let savedPlaceRadius: CLLocationDistance = 80

    /// Grid size for rounding (~0.0003 degrees ≈ 33m at equator)
    private let gridStep: Double = 0.0003

    // MARK: - Init

    private init() {
        loadSavedPlaces()
    }

    // MARK: - Grid Key

    /// Round lat/lon to a grid cell and return a stable string key.
    func gridKey(for location: CLLocation) -> String {
        let lat = (location.coordinate.latitude / gridStep).rounded() * gridStep
        let lon = (location.coordinate.longitude / gridStep).rounded() * gridStep
        return String(format: "%.4f,%.4f", lat, lon)
    }

    // MARK: - Cache Operations

    func cachedName(for location: CLLocation) -> String? {
        let key = gridKey(for: location)
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    func store(name: String, for location: CLLocation) {
        let key = gridKey(for: location)
        lock.lock()
        cache[key] = name
        lock.unlock()
    }

    // MARK: - Saved Places

    /// Returns the closest saved place within the proximity threshold, or nil.
    func matchSavedPlace(for location: CLLocation) -> SavedPlace? {
        var best: (place: SavedPlace, distance: CLLocationDistance)?

        for place in savedPlaces {
            let distance = location.distance(from: place.location)
            if distance <= savedPlaceRadius {
                if best == nil || distance < best!.distance {
                    best = (place, distance)
                }
            }
        }

        return best?.place
    }

    func addSavedPlace(label: String, location: CLLocation, name: String) {
        let place = SavedPlace(
            id: UUID(),
            label: label,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            name: name
        )
        savedPlaces.append(place)
        persistSavedPlaces()
    }

    func removeSavedPlace(id: UUID) {
        savedPlaces.removeAll { $0.id == id }
        persistSavedPlaces()
    }

    // MARK: - Persistence

    private func loadSavedPlaces() {
        guard let data = UserDefaults.standard.data(forKey: savedPlacesKey),
              let decoded = try? JSONDecoder().decode([SavedPlace].self, from: data) else {
            return
        }
        savedPlaces = decoded
    }

    private func persistSavedPlaces() {
        guard let data = try? JSONEncoder().encode(savedPlaces) else { return }
        UserDefaults.standard.set(data, forKey: savedPlacesKey)
    }
}
