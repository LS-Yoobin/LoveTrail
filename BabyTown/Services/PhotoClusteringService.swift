import CoreLocation

class PhotoClusteringService {
    
    // Distance threshold: 300 meters (adjustable)
    private let distanceThreshold: CLLocationDistance = 300
    
    // Time threshold: 6 hours (adjustable)
    private let timeThreshold: TimeInterval = 6 * 3600
    
    func clusterPhotos(_ photos: [PhotoMetadata]) async -> [PhotoCluster] {
        // Already sorted by creation date from fetch
        var clusters: [PhotoCluster] = []
        
        for photo in photos {
            if let clusterIndex = findMatchingCluster(for: photo, in: clusters) {
                // Add to existing cluster
                clusters[clusterIndex].photos.append(photo)
                
                // Update cluster metadata
                updateClusterMetadata(&clusters[clusterIndex])
            } else {
                // Create new cluster
                let newCluster = PhotoCluster(
                    photos: [photo],
                    centerCoordinate: photo.coordinate,
                    dateRange: DateInterval(start: photo.creationDate, end: photo.creationDate)
                )
                clusters.append(newCluster)
            }
        }
        
        // Sort clusters by most recent date
        return clusters.sorted { $0.dateRange.end > $1.dateRange.end }
    }
    
    private func findMatchingCluster(for photo: PhotoMetadata, in clusters: [PhotoCluster]) -> Int? {
        for (index, cluster) in clusters.enumerated() {
            // Check distance to cluster center
            let distance = calculateDistance(
                from: photo.coordinate,
                to: cluster.centerCoordinate
            )
            
            guard distance <= distanceThreshold else { continue }
            
            // Check time gap from last photo in cluster
            guard let lastPhoto = cluster.lastPhoto else { continue }
            let timeGap = photo.creationDate.timeIntervalSince(lastPhoto.creationDate)
            
            // If time gap exceeds threshold, don't add to cluster (split into new one)
            guard timeGap <= timeThreshold else { continue }
            
            // Both conditions met
            return index
        }
        
        return nil
    }
    
    private func updateClusterMetadata(_ cluster: inout PhotoCluster) {
        // Recalculate center coordinate (average of all photos)
        let totalLat = cluster.photos.reduce(0.0) { $0 + $1.coordinate.latitude }
        let totalLon = cluster.photos.reduce(0.0) { $0 + $1.coordinate.longitude }
        
        cluster.centerCoordinate = CLLocationCoordinate2D(
            latitude: totalLat / Double(cluster.photos.count),
            longitude: totalLon / Double(cluster.photos.count)
        )
        
        // Update date range
        if let first = cluster.photos.first, let last = cluster.photos.last {
            cluster.dateRange = DateInterval(
                start: first.creationDate,
                end: last.creationDate
            )
        }
    }
    
    private func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
}
