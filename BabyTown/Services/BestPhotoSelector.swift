import Photos
import UIKit

class BestPhotoSelector {
    
    func selectBestPhoto(from cluster: PhotoCluster) async -> PhotoMetadata? {
        var scoredPhotos: [(photo: PhotoMetadata, score: Double)] = []
        
        for photo in cluster.photos {
            let score = await calculateQualityScore(for: photo)
            scoredPhotos.append((photo, score))
        }
        
        // Return photo with highest score
        return scoredPhotos.max(by: { $0.score < $1.score })?.photo
    }
    
    func selectSecondaryPhotos(
        from cluster: PhotoCluster,
        excluding primary: PhotoMetadata,
        limit: Int = 3
    ) async -> [PhotoMetadata] {
        let candidates = cluster.photos.filter { $0.asset.localIdentifier != primary.asset.localIdentifier }
        
        var scoredPhotos: [(photo: PhotoMetadata, score: Double)] = []
        
        for photo in candidates {
            let score = await calculateQualityScore(for: photo)
            scoredPhotos.append((photo, score))
        }
        
        // Sort by score and take top N
        return scoredPhotos
            .sorted(by: { $0.score > $1.score })
            .prefix(limit)
            .map { $0.photo }
    }
    
    private func calculateQualityScore(for photo: PhotoMetadata) async -> Double {
        var score = 0.0
        
        // 1. Resolution score (0-30 points)
        let pixels = Double(photo.pixelWidth * photo.pixelHeight)
        let resolutionScore = min(30.0, (pixels / 1_000_000) * 10) // 3MP = 30 points
        score += resolutionScore
        
        // 2. Aspect ratio score (0-10 points) - prefer standard ratios
        let aspectRatio = Double(photo.pixelWidth) / Double(photo.pixelHeight)
        let aspectScore: Double
        if (0.6...0.8).contains(aspectRatio) || (1.2...1.7).contains(aspectRatio) {
            aspectScore = 10.0 // Standard portrait/landscape
        } else if (0.9...1.1).contains(aspectRatio) {
            aspectScore = 8.0 // Square
        } else {
            aspectScore = 5.0 // Unusual ratio
        }
        score += aspectScore
        
        // 3. Image quality heuristic (0-20 points)
        // Simple baseline score for now
        score += 20.0
        
        return score
    }
}
