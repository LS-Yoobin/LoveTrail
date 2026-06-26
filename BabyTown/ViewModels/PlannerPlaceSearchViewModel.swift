import Combine
import CoreLocation
import MapKit

final class PlannerPlaceSearchViewModel: NSObject, ObservableObject {
    @Published var query: String = ""
    @Published var suggestions: [PlaceSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]

        $query
            .debounce(for: .seconds(0.3), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newQuery in
                guard let self else { return }
                if newQuery.isEmpty {
                    self.suggestions = []
                } else {
                    self.completer.queryFragment = newQuery
                }
            }
            .store(in: &cancellables)
    }

    func resolveDetails(for suggestion: PlaceSuggestion) async -> CLLocationCoordinate2D? {
        guard case .mapKit(let completion) = suggestion.source else { return nil }
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        guard let response = try? await search.start(),
              let mapItem = response.mapItems.first else { return nil }
        return mapItem.placemark.coordinate
    }
}

extension PlannerPlaceSearchViewModel: MKLocalSearchCompleterDelegate {
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
