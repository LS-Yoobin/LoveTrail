import SwiftUI

struct CameraLogEntryRow: View {
    let capturedAt: Date
    let placeName: String?
    
    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    
    private var timeString: String {
        let now = Date()
        let relative = relativeFormatter.localizedString(for: capturedAt, relativeTo: now)
        return "Taken \(relative)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timeString)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            if let place = placeName {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                    Text(place)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    VStack(alignment: .leading) {
        CameraLogEntryRow(capturedAt: Date().addingTimeInterval(-7200), placeName: "The Battery")
        Divider()
        CameraLogEntryRow(capturedAt: Date().addingTimeInterval(-300), placeName: "SoMa")
    }
    .padding()
}
