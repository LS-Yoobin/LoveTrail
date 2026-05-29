import Combine
import CoreLocation
import MapKit
import SwiftUI

struct MapTapPOICandidate: Identifiable, Hashable {
    var id: String { "\(name)|\(coordinate.latitude)|\(coordinate.longitude)" }
    let name: String
    let coordinate: CLLocationCoordinate2D
    let distanceMeters: Double

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(distanceMeters)
    }

    static func == (lhs: MapTapPOICandidate, rhs: MapTapPOICandidate) -> Bool {
        lhs.name == rhs.name
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.distanceMeters == rhs.distanceMeters
    }
}

enum MapTapPOIResult {
    case none
    case single(name: String, coordinate: CLLocationCoordinate2D)
    case ambiguous(candidates: [MapTapPOICandidate])
}

/// MapKit autocomplete + POI resolution for memory location editing (mirrors fastblog PlaceSearchViewModel, MapKit-only).
final class MemoryPlaceSearchViewModel: NSObject, ObservableObject {
    @Published var query: String = ""
    @Published var suggestions: [PlaceSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()
    private var biasCoordinate: CLLocationCoordinate2D?

    var biasRegion: MKCoordinateRegion? {
        didSet {
            if let region = biasRegion {
                completer.region = region
            }
        }
    }

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]

        $query
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newQuery in
                self?.updateSearch(query: newQuery)
            }
            .store(in: &cancellables)
    }

    func setBiasLocation(_ coordinate: CLLocationCoordinate2D?) {
        guard let coordinate else { return }
        biasCoordinate = coordinate
        biasRegion = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )
    }

    private func updateSearch(query: String) {
        if query.isEmpty {
            suggestions = []
            return
        }
        completer.queryFragment = query
    }

    func resolveDetails(for suggestion: PlaceSuggestion) async -> CLLocationCoordinate2D? {
        guard case .mapKit(let completion) = suggestion.source else { return nil }
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(),
              let mapItem = response.mapItems.first else {
            return nil
        }
        return mapItem.placemark.coordinate
    }

    func resolveCoordinateName(at coordinate: CLLocationCoordinate2D) async -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return await SmartPlaceResolver.shared.resolvePlaceName(for: location)
    }

    private static func tapSearchRadiusMeters(mapRegion: MKCoordinateRegion?) -> Double {
        if let region = mapRegion {
            let metersPerPoint = region.span.latitudeDelta * 111_000.0 / 500.0
            return max(25.0, min(80.0, metersPerPoint * 22.0))
        }
        return 80.0
    }

    private static let widePOIFallbackRadiusMeters: Double = 250

    func resolveMapTapPOI(near coordinate: CLLocationCoordinate2D, mapRegion: MKCoordinateRegion? = nil) async -> MapTapPOIResult {
        let strictRadius = Self.tapSearchRadiusMeters(mapRegion: mapRegion)
        let strict = await searchPOINearTap(coordinate: coordinate, radius: strictRadius)
        if case .none = strict {
            return await searchPOINearTap(coordinate: coordinate, radius: Self.widePOIFallbackRadiusMeters)
        }
        return strict
    }

    private func searchPOINearTap(coordinate: CLLocationCoordinate2D, radius: Double) async -> MapTapPOIResult {
        let tapLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: radius)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(), !response.mapItems.isEmpty else { return .none }

        let withName = response.mapItems.filter {
            !($0.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let scored: [(item: MKMapItem, distance: Double)] = withName.compactMap { item in
            let loc = item.placemark.location
                ?? CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
            let d = tapLocation.distance(from: loc)
            guard d <= radius else { return nil }
            return (item, d)
        }
        .sorted { $0.distance < $1.distance }

        guard let first = scored.first else { return .none }

        let gapToSecond = scored.count >= 2 ? scored[1].distance - first.distance : .greatestFiniteMagnitude
        let ambiguousGapMeters: Double = 22

        if scored.count >= 2, gapToSecond < ambiguousGapMeters {
            let capped = scored.prefix(8).map { pair in
                MapTapPOICandidate(
                    name: (pair.item.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    coordinate: pair.item.placemark.coordinate,
                    distanceMeters: pair.distance
                )
            }
            return .ambiguous(candidates: Array(capped))
        }

        let name = (first.item.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .none }
        return .single(name: name, coordinate: first.item.placemark.coordinate)
    }
}

extension MemoryPlaceSearchViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results.map { completion in
            PlaceSuggestion(
                id: "\(completion.title)|\(completion.subtitle)",
                title: completion.title,
                subtitle: completion.subtitle,
                source: .mapKit(completion)
            )
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
