import CoreLocation
import MapKit

enum PlaceSuggestionSource {
    case mapKit(MKLocalSearchCompletion)
}

struct PlaceSuggestion: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let source: PlaceSuggestionSource
}
