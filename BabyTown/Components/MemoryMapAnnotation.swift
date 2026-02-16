import Foundation
import MapKit

class MemoryMapAnnotation: NSObject, Identifiable, MKAnnotation {
    let id: UUID
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
        self.id = UUID()
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
