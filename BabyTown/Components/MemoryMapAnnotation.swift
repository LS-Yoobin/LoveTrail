import Foundation
import MapKit

class MemoryMapAnnotation: NSObject, Identifiable, MKAnnotation {
    /// Stable across re-filtering: derived from the section, not a random UUID.
    /// A random id would make every `updateAnnotations()` look like a brand-new set,
    /// forcing a full remove/re-add that re-clusters (and visibly disperses) the map.
    let id: String
    let coordinate: CLLocationCoordinate2D
    let section: DaySection
    
    var title: String? {
        section.placeName ?? "Memory"
    }
    
    var subtitle: String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: section.date)
    }
    
    init(section: DaySection) {
        self.id = section.id
        self.section = section
        
        // Use the first moment's location as the pin coordinate
        if let firstMoment = section.moments.first,
           let location = firstMoment.location {
            self.coordinate = location.coordinate
        } else {
            // Fallback coordinate (should never happen if filtered correctly)
            self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        super.init()
    }
}

// MARK: - App-controlled clustering

/// A group of memory annotations rendered as a single count marker.
///
/// Unlike `MKClusterAnnotation`, these are produced by us (not MapKit) so the grouping is
/// fully deterministic: it depends only on the map span, not on MapKit's add/remove-driven
/// re-clustering pass. Filter changes therefore add/remove plain pins without the cascade
/// reshuffle that native clustering performs whenever annotations are added.
final class MemoryClusterAnnotation: NSObject, MKAnnotation {
    let members: [MemoryMapAnnotation]
    let coordinate: CLLocationCoordinate2D
    /// Stable for the same member set, so panning (no span change) yields an identical
    /// cluster set and the annotation diff is a no-op.
    let id: String

    var count: Int { members.count }

    init(members: [MemoryMapAnnotation]) {
        self.members = members
        let count = Double(members.count)
        self.coordinate = CLLocationCoordinate2D(
            latitude: members.map(\.coordinate.latitude).reduce(0, +) / count,
            longitude: members.map(\.coordinate.longitude).reduce(0, +) / count
        )
        self.id = members.map(\.id).sorted().joined(separator: "|")
        super.init()
    }
}

/// Stable string identity for diffing whichever annotation kind we render.
func memoryMapAnnotationID(_ annotation: MKAnnotation) -> String? {
    if let single = annotation as? MemoryMapAnnotation { return "single:\(single.id)" }
    if let cluster = annotation as? MemoryClusterAnnotation { return "cluster:\(cluster.id)" }
    return nil
}

/// Groups memory annotations into clusters based on the current map `span`.
///
/// - Below `clusterCutoffSpan` (neighborhood zoom) every memory is its own pin, so zooming in
///   always breaks clusters apart — matching the "stays as-is until the user zooms" behavior.
/// - At larger spans the cluster radius scales with the visible range, so grouping feels
///   consistent at every zoom level.
///
/// Greedy nearest-center assignment: O(n²), fine for the small memory counts in practice.
func clusterMemoryAnnotations(
    _ annotations: [MemoryMapAnnotation],
    span: MKCoordinateSpan
) -> [MKAnnotation] {
    let clusterCutoffSpan: CLLocationDegrees = 0.15
    guard span.latitudeDelta >= clusterCutoffSpan else {
        return annotations
    }

    let radiusDeg = max(0.05, span.latitudeDelta * 0.12)
    var centers: [CLLocationCoordinate2D] = []
    var groups: [[MemoryMapAnnotation]] = []

    for item in annotations {
        let coord = item.coordinate
        // Correct longitude tolerance for latitude distortion.
        let lonFactor = max(0.01, cos(coord.latitude * .pi / 180))
        if let idx = centers.indices.first(where: { i in
            abs(centers[i].latitude - coord.latitude) < radiusDeg &&
            abs(centers[i].longitude - coord.longitude) < radiusDeg / lonFactor
        }) {
            groups[idx].append(item)
        } else {
            centers.append(coord)
            groups.append([item])
        }
    }

    return groups.compactMap { group -> MKAnnotation? in
        guard let first = group.first else { return nil }
        return group.count == 1 ? first : MemoryClusterAnnotation(members: group)
    }
}
