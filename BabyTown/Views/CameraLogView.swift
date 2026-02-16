import SwiftUI

struct CameraLogView: View {
    let entries: [PolaroidEntry]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Today's Captures")
                    .font(.system(size: 20, weight: .bold))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "camera.badge.ellipsis")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("No photos captured yet today")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(entries.sorted(by: { $0.capturedAt > $1.capturedAt })) { entry in
                            CameraLogEntryRow(capturedAt: entry.capturedAt, placeName: entry.placeName)
                                .padding(.horizontal, 24)
                            
                            if entry.id != entries.sorted(by: { $0.capturedAt > $1.capturedAt }).last?.id {
                                Divider()
                                    .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
    }
}

#Preview {
    CameraLogView(entries: [
        PolaroidEntry(id: UUID(), capturedAt: Date().addingTimeInterval(-3600), imageFileName: "", released: false, placeName: "Golden Gate Park"),
        PolaroidEntry(id: UUID(), capturedAt: Date().addingTimeInterval(-7200), imageFileName: "", released: false, placeName: "Ocean Beach")
    ])
}
