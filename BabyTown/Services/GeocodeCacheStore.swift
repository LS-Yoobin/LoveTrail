import CoreLocation
import Foundation

/// Persistent cache for reverse-geocode API results, keyed by rounded coordinates (~100m grid).
/// Survives app restarts so scans and imports skip redundant geocode calls.
final class GeocodeCacheStore {

    static let shared = GeocodeCacheStore()

    struct Entry: Codable, Equatable {
        let placeName: String?
        let country: String?
    }

    private var memory: [String: Entry] = [:]
    private let lock = NSLock()
    private let storageKey = "BabyTown_GeocodeCache"

    private init() {
        loadFromDisk()
    }

    func entry(for coordinate: CLLocationCoordinate2D) -> Entry? {
        entry(forKey: ReverseGeocodeService.coordinateCacheKey(for: coordinate))
    }

    func entry(forKey key: String) -> Entry? {
        lock.lock()
        defer { lock.unlock() }
        return memory[key]
    }

    func store(placeName: String?, country: String?, for coordinate: CLLocationCoordinate2D) {
        store(
            Entry(placeName: placeName, country: country),
            forKey: ReverseGeocodeService.coordinateCacheKey(for: coordinate)
        )
    }

    func store(_ entry: Entry, forKey key: String) {
        lock.lock()
        let existing = memory[key]
        memory[key] = entry
        lock.unlock()

        guard existing != entry else { return }
        persistToDisk()
    }

    func clear() {
        lock.lock()
        memory.removeAll()
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func loadFromDisk() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else {
            return
        }
        memory = decoded
    }

    private func persistToDisk() {
        lock.lock()
        let snapshot = memory
        lock.unlock()

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
