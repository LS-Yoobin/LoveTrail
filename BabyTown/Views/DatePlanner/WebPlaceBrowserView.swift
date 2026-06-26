import SwiftUI
import WebKit
import CoreLocation

enum WebPlaceSource: Identifiable {
    case googleMaps
    case yelp

    var id: String {
        switch self {
        case .googleMaps: return "googleMaps"
        case .yelp: return "yelp"
        }
    }

    var startURL: URL {
        switch self {
        case .googleMaps: return URL(string: "https://www.google.com/maps")!
        case .yelp: return URL(string: "https://www.yelp.com")!
        }
    }

    var label: String {
        switch self {
        case .googleMaps: return "Google Maps"
        case .yelp: return "Yelp"
        }
    }
}

struct WebDetectedPlace {
    let name: String
    let latitude: Double?
    let longitude: Double?
}

struct WebPlaceBrowserView: View {
    let source: WebPlaceSource
    let onAdd: (ItineraryStop) -> Void
    let nextOrder: Int
    var assignDay: Int = 1

    @Environment(\.dismiss) private var dismiss
    @State private var detectedPlace: WebDetectedPlace?
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                WebKitBrowserView(source: source) { place in
                    withAnimation(.spring(response: 0.4)) {
                        detectedPlace = place
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                if let place = detectedPlace {
                    addButton(place)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: detectedPlace != nil)
            .navigationTitle(source.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(BabyTownTheme.accent)
                }
            }
        }
    }

    private func addButton(_ place: WebDetectedPlace) -> some View {
        Button {
            guard !isAdding else { return }
            isAdding = true
            Task { await commitPlace(place) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text("Add \"\(place.name)\"")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(BabyTownTheme.accentGradient, in: Capsule())
            .shadow(color: BabyTownTheme.accent.opacity(0.4), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .opacity(isAdding ? 0.6 : 1)
        .disabled(isAdding)
    }

    private func commitPlace(_ place: WebDetectedPlace) async {
        defer {
            Task { @MainActor in isAdding = false }
        }

        var lat = place.latitude
        var lng = place.longitude

        if lat == nil || lng == nil {
            let geocoder = CLGeocoder()
            if let placemark = try? await geocoder.geocodeAddressString(place.name).first,
               let loc = placemark.location {
                lat = loc.coordinate.latitude
                lng = loc.coordinate.longitude
            }
        }

        let stop = ItineraryStop(
            id: UUID(),
            order: nextOrder,
            day: assignDay,
            placeName: place.name,
            latitude: lat,
            longitude: lng,
            momentID: nil,
            photoData: nil,
            note: nil
        )

        await MainActor.run {
            onAdd(stop)
            dismiss()
        }
    }
}

// MARK: - WKWebView wrapper

struct WebKitBrowserView: UIViewRepresentable {
    let source: WebPlaceSource
    let onPlaceDetected: (WebDetectedPlace?) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.startObserving(webView)
        webView.load(URLRequest(url: source.startURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(source: source, onPlaceDetected: onPlaceDetected)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let source: WebPlaceSource
        let onPlaceDetected: (WebDetectedPlace?) -> Void
        private var urlObservation: NSKeyValueObservation?
        private var lastProcessedURL: String?

        init(source: WebPlaceSource, onPlaceDetected: @escaping (WebDetectedPlace?) -> Void) {
            self.source = source
            self.onPlaceDetected = onPlaceDetected
        }

        func startObserving(_ webView: WKWebView) {
            urlObservation = webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                guard let self, let url = webView.url else { return }
                DispatchQueue.main.async {
                    self.handleNavigation(to: url, webView: webView)
                }
            }
        }

        func stopObserving() {
            urlObservation?.invalidate()
            urlObservation = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else {
                DispatchQueue.main.async { self.onPlaceDetected(nil) }
                return
            }
            handleNavigation(to: url, webView: webView)
        }

        private func handleNavigation(to url: URL, webView: WKWebView) {
            let urlString = url.absoluteString
            guard urlString != lastProcessedURL else { return }
            lastProcessedURL = urlString

            switch source {
            case .googleMaps:
                extractGoogleMapsPlace(from: url, webView: webView)
            case .yelp:
                extractYelpPlace(from: url, webView: webView)
            }
        }

        private func extractGoogleMapsPlace(from url: URL, webView: WKWebView) {
            let str = url.absoluteString
            let isPlacePage = str.contains("/maps/place/")
                || (str.contains("/maps") && str.contains("!1s"))

            guard isPlacePage else {
                DispatchQueue.main.async { self.onPlaceDetected(nil) }
                return
            }

            var name = Self.placeName(from: url)
            let coordinates = Self.googleMapsCoordinates(from: str)

            if name.isEmpty {
                extractGoogleMapsNameViaJS(webView: webView, latitude: coordinates.latitude, longitude: coordinates.longitude)
                return
            }

            let place = WebDetectedPlace(name: name, latitude: coordinates.latitude, longitude: coordinates.longitude)
            DispatchQueue.main.async { self.onPlaceDetected(place) }
        }

        private func extractGoogleMapsNameViaJS(webView: WKWebView, latitude: Double?, longitude: Double?) {
            let js = """
            (function() {
                var h1 = document.querySelector('h1');
                if (h1 && h1.innerText.trim()) {
                    return h1.innerText.trim();
                }
                var title = document.querySelector('[data-attrid="title"]');
                if (title && title.innerText.trim()) {
                    return title.innerText.trim();
                }
                return '';
            })()
            """

            webView.evaluateJavaScript(js) { [weak self] result, _ in
                guard let self else { return }
                guard let name = result as? String, !name.isEmpty else {
                    DispatchQueue.main.async { self.onPlaceDetected(nil) }
                    return
                }
                let place = WebDetectedPlace(name: name, latitude: latitude, longitude: longitude)
                DispatchQueue.main.async { self.onPlaceDetected(place) }
            }
        }

        private static func placeName(from url: URL) -> String {
            let path = url.path
            guard let range = path.range(of: "/maps/place/") else { return "" }
            let after = String(path[range.upperBound...])
            let segment = after.components(separatedBy: "/").first ?? ""
            let decoded = segment.removingPercentEncoding ?? segment
            return decoded
                .replacingOccurrences(of: "+", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private static func googleMapsCoordinates(from urlString: String) -> (latitude: Double?, longitude: Double?) {
            if let match = firstRegexMatch(
                pattern: #"!3d(-?\d+\.?\d*)!4d(-?\d+\.?\d*)"#,
                in: urlString
            ),
               let lat = Double(match.0),
               let lng = Double(match.1) {
                return (lat, lng)
            }

            if let match = firstRegexMatch(
                pattern: #"@(-?\d+\.?\d*),(-?\d+\.?\d*)"#,
                in: urlString
            ),
               let lat = Double(match.0),
               let lng = Double(match.1) {
                return (lat, lng)
            }

            return (nil, nil)
        }

        private static func firstRegexMatch(pattern: String, in text: String) -> (String, String)? {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let r1 = Range(match.range(at: 1), in: text),
                  let r2 = Range(match.range(at: 2), in: text) else {
                return nil
            }
            return (String(text[r1]), String(text[r2]))
        }

        private func extractYelpPlace(from url: URL, webView: WKWebView) {
            guard url.absoluteString.contains("yelp.com/biz/") else {
                DispatchQueue.main.async { self.onPlaceDetected(nil) }
                return
            }

            let js = """
            (function() {
                var scripts = document.querySelectorAll('script[type="application/ld+json"]');
                for (var s of scripts) {
                    try {
                        var d = JSON.parse(s.textContent);
                        var items = Array.isArray(d) ? d : [d];
                        for (var item of items) {
                            if (item.name) {
                                return JSON.stringify({
                                    name: item.name,
                                    lat: item.geo ? item.geo.latitude : null,
                                    lng: item.geo ? item.geo.longitude : null
                                });
                            }
                        }
                    } catch(e) {}
                }
                var h1 = document.querySelector('h1');
                return JSON.stringify({name: h1 ? h1.innerText.trim() : '', lat: null, lng: null});
            })()
            """

            webView.evaluateJavaScript(js) { [weak self] result, _ in
                guard let self else { return }
                guard let jsonStr = result as? String,
                      let data = jsonStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let name = json["name"] as? String, !name.isEmpty else {
                    DispatchQueue.main.async { self.onPlaceDetected(nil) }
                    return
                }
                let lat = (json["lat"] as? NSNumber)?.doubleValue
                let lng = (json["lng"] as? NSNumber)?.doubleValue
                let place = WebDetectedPlace(name: name, latitude: lat, longitude: lng)
                DispatchQueue.main.async { self.onPlaceDetected(place) }
            }
        }
    }
}
