import Foundation
import MapKit

class MemoryMapAnnotation: NSObject, Identifiable, MKAnnotation {
    /// Stable across re-filtering: derived from the section, not a random UUID.
    /// A random id would make every `updateAnnotations()` look like a brand-new set,
    /// forcing a full remove/re-add that re-clusters (and visibly disperses) the map.
    let id: String
    let coordinate: CLLocationCoordinate2D
    let section: DaySection
    let showsPhotoThumbnail: Bool
    let isVaulted: Bool
    
    var title: String? {
        section.placeName ?? "Memory"
    }
    
    var subtitle: String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: section.date)
    }
    
    init(section: DaySection, showsPhotoThumbnail: Bool = true, isVaulted: Bool = false) {
        self.id = section.id
        self.section = section
        self.showsPhotoThumbnail = showsPhotoThumbnail
        self.isVaulted = isVaulted
        
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
/// Grid-bucket clustering: O(n). Re-clusters only when span changes meaningfully.
func clusterMemoryAnnotations(
    _ annotations: [MemoryMapAnnotation],
    span: MKCoordinateSpan
) -> [MKAnnotation] {
    let clusterCutoffSpan: CLLocationDegrees = 0.15
    let largePinCountThreshold = 30
    let forceCluster = annotations.count > largePinCountThreshold

    guard span.latitudeDelta >= clusterCutoffSpan || forceCluster else {
        return annotations
    }

    let radiusDeg = max(0.05, span.latitudeDelta * 0.12)
    let cellSize: CLLocationDegrees = forceCluster && span.latitudeDelta < clusterCutoffSpan
        ? max(0.005, span.latitudeDelta * 0.15)
        : radiusDeg

    var cellToGroupIndex: [String: Int] = [:]
    var groups: [[MemoryMapAnnotation]] = []

    for item in annotations {
        let coord = item.coordinate
        let lonFactor = max(0.01, cos(coord.latitude * .pi / 180))
        let latCell = Int(floor(coord.latitude / cellSize))
        let lonCell = Int(floor(coord.longitude / (cellSize / lonFactor)))

        var assigned = false
        for dLat in -1...1 where !assigned {
            for dLon in -1...1 {
                let key = "\(latCell + dLat),\(lonCell + dLon)"
                if let idx = cellToGroupIndex[key] {
                    groups[idx].append(item)
                    cellToGroupIndex["\(latCell),\(lonCell)"] = idx
                    assigned = true
                    break
                }
            }
        }

        if !assigned {
            let idx = groups.count
            groups.append([item])
            cellToGroupIndex["\(latCell),\(lonCell)"] = idx
        }
    }

    return groups.compactMap { group -> MKAnnotation? in
        guard let first = group.first else { return nil }
        return group.count == 1 ? first : MemoryClusterAnnotation(members: group)
    }
}

func mapSpanChangedSignificantly(from old: MKCoordinateSpan?, to new: MKCoordinateSpan) -> Bool {
    guard let old else { return true }
    let latRatio = abs(new.latitudeDelta - old.latitudeDelta) / max(old.latitudeDelta, 0.0001)
    let lonRatio = abs(new.longitudeDelta - old.longitudeDelta) / max(old.longitudeDelta, 0.0001)
    return latRatio > 0.08 || lonRatio > 0.08
}

/// Builds a map region that fits all coordinates, including sets that cross the antimeridian.
func coordinateRegion(
    fitting coordinates: [CLLocationCoordinate2D],
    paddingFactor: Double = 1.5,
    minimumSpan: CLLocationDegrees = 0.05,
    maximumLatitudeSpan: CLLocationDegrees = 80,
    maximumLongitudeSpan: CLLocationDegrees = 360
) -> MKCoordinateRegion? {
    guard !coordinates.isEmpty else { return nil }

    var mapRect = coordinates.reduce(MKMapRect.null) { rect, coordinate in
        let point = MKMapPoint(coordinate)
        let pointRect = MKMapRect(origin: point, size: MKMapSize())
        return rect.isNull ? pointRect : rect.union(pointRect)
    }

    if paddingFactor > 1 {
        let padX = mapRect.size.width * (paddingFactor - 1) / 2
        let padY = mapRect.size.height * (paddingFactor - 1) / 2
        mapRect = mapRect.insetBy(dx: -padX, dy: -padY)
    }

    var region = MKCoordinateRegion(mapRect)
    region.span.latitudeDelta = min(
        max(region.span.latitudeDelta, minimumSpan),
        maximumLatitudeSpan
    )
    region.span.longitudeDelta = min(
        max(region.span.longitudeDelta, minimumSpan),
        maximumLongitudeSpan
    )
    return region
}

/// Clamps a region to values MapKit accepts so `setRegion` cannot crash.
func sanitizedMapRegion(_ region: MKCoordinateRegion) -> MKCoordinateRegion {
    var sanitized = region
    sanitized.center.latitude = min(max(sanitized.center.latitude, -90), 90)

    var longitude = sanitized.center.longitude.truncatingRemainder(dividingBy: 360)
    if longitude > 180 { longitude -= 360 }
    if longitude < -180 { longitude += 360 }
    sanitized.center.longitude = longitude

    sanitized.span.latitudeDelta = min(max(sanitized.span.latitudeDelta, 0.001), 180)
    sanitized.span.longitudeDelta = min(max(sanitized.span.longitudeDelta, 0.001), 360)
    return sanitized
}
