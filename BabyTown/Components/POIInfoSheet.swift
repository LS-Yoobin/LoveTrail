import SwiftUI
import CoreLocation

/// Pull-up sheet shown when a user taps an Apple Maps POI. Loads a Google search
/// for the place name + reverse-geocoded city in an in-app web view.
struct POIInfoSheet: View {
    let placeName: String
    let coordinate: CLLocationCoordinate2D

    @Environment(\.dismiss) private var dismiss
    @State private var resolvedCity: String?
    @State private var searchReady = false

    private var displayName: String {
        placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nearby Place" : placeName
    }

    private var googleSearchURL: URL {
        var query = displayName
        if let city = resolvedCity { query += " \(city)" }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: "https://www.google.com/search?q=\(encoded)")
            ?? URL(string: "https://www.google.com/search")!
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(white: 0.5).opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 12)

            HStack(alignment: .center) {
                Text(displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(BabyTownTheme.accent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            Divider()

            if searchReady {
                EmbeddedWebView(url: googleSearchURL)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .task {
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                resolvedCity = placemark.locality ?? placemark.administrativeArea
            }
            searchReady = true
        }
    }
}
