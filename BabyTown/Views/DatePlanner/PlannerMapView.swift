import SwiftUI
import MapKit

// MARK: - Non-interactive map card

struct PlannerMapView: View {
    let stops: [ItineraryStop]

    var body: some View {
        PlannerMapContentView(stops: stops, isInteractive: false)
    }
}

// MARK: - Full-screen interactive map

struct PlannerFullMapView: View {
    let stops: [ItineraryStop]
    @Environment(\.dismiss) private var dismiss
    @State private var showPOISheet = false
    @State private var activePOISelection: POISelection?
    @State private var selectedStop: ItineraryStop?
    @State private var focusedStopID: UUID?

    private var orderedStops: [ItineraryStop] {
        stops.sorted { $0.order < $1.order }
    }

    var body: some View {
        NavigationStack {
            PlannerMapContentView(
                stops: stops,
                isInteractive: true,
                focusedStopID: $focusedStopID,
                onSelectStop: { stop in
                    focusedStopID = stop.id
                    selectedStop = stop
                },
                onSelectPOI: { title, coordinate in
                    activePOISelection = POISelection(title: title, coordinate: coordinate)
                    showPOISheet = true
                }
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !orderedStops.isEmpty {
                    PlannerMapStopCarousel(
                        stops: orderedStops,
                        focusedStopID: $focusedStopID
                    )
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                        .foregroundStyle(BabyTownTheme.accent)
                }
            }
            .onAppear {
                if focusedStopID == nil {
                    focusedStopID = orderedStops.first?.id
                }
            }
        }
        .sheet(isPresented: $showPOISheet, onDismiss: {
            activePOISelection = nil
        }) {
            if let selection = activePOISelection {
                POIInfoSheet(placeName: selection.title, coordinate: selection.coordinate)
            }
        }
        .sheet(item: $selectedStop) { stop in
            StopDetailSheet(stop: stop, showsRemoveAction: false, onRemove: {})
        }
    }
}

// MARK: - Shared map

private struct PlannerMapContentView: View {
    let stops: [ItineraryStop]
    var isInteractive: Bool
    var focusedStopID: Binding<UUID?> = .constant(nil)
    var onSelectStop: (ItineraryStop) -> Void = { _ in }
    var onSelectPOI: (_ title: String, _ coordinate: CLLocationCoordinate2D) -> Void = { _, _ in }

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedMapFeature: MapFeature?

    private var orderedStops: [ItineraryStop] {
        stops.sorted { $0.order < $1.order }
    }

    private var geoStops: [ItineraryStop] {
        orderedStops.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        geoStops.compactMap { stop in
            guard let lat = stop.latitude, let lon = stop.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
    }

    var body: some View {
        Group {
            if isInteractive {
                Map(position: $cameraPosition, selection: $selectedMapFeature) {
                    plannerMapContent
                }
            } else {
                Map(position: $cameraPosition, interactionModes: []) {
                    plannerMapContent
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .onChange(of: selectedMapFeature) { _, newFeature in
            guard isInteractive, let newFeature else { return }
            onSelectPOI(newFeature.title ?? "", newFeature.coordinate)
            selectedMapFeature = nil
        }
        .onAppear {
            updateCameraPosition(animated: false)
        }
        .onChange(of: stops.map(\.id)) { _, _ in
            updateCameraPosition(animated: !isInteractive)
        }
        .onChange(of: focusedStopID.wrappedValue) { oldID, newID in
            guard isInteractive, oldID != nil, let newID else { return }
            centerOnStop(id: newID, animated: true)
        }
    }

    @MapContentBuilder
    private var plannerMapContent: some MapContent {
        if routeCoordinates.count >= 2 {
            MapPolyline(coordinates: routeCoordinates)
                .stroke(
                    BabyTownTheme.accent,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [6, 4])
                )
        }

        ForEach(geoStops) { stop in
            if let lat = stop.latitude, let lon = stop.longitude {
                Annotation(
                    "",
                    coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    anchor: markerAnchor(hasPlaceName: !stop.placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                ) {
                    Button {
                        onSelectStop(stop)
                    } label: {
                        PlannerStopMarkerView(
                            order: stop.order,
                            badgeStyle: PlannerStopBadgeStyle.forStop(stop, in: orderedStops),
                            photoData: stop.photoData,
                            placeName: stop.placeName
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Keeps the pin circle on the coordinate with the name pill hanging below.
    private func markerAnchor(hasPlaceName: Bool) -> UnitPoint {
        let circleHeight: CGFloat = 28
        let spacing: CGFloat = 4
        let pillHeight: CGFloat = hasPlaceName ? 22 : 0
        let total = circleHeight + spacing + pillHeight
        return UnitPoint(x: 0.5, y: circleHeight / total)
    }

    private func centerOnStop(id: UUID, animated: Bool) {
        guard let stop = geoStops.first(where: { $0.id == id }),
              let lat = stop.latitude,
              let lon = stop.longitude else { return }

        let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )

        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
    }

    private func updateCameraPosition(animated: Bool) {
        guard !routeCoordinates.isEmpty else { return }
        let region = regionFitting(routeCoordinates)
        if animated {
            withAnimation(.easeInOut(duration: 0.35)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
    }

    private func regionFitting(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLon = coords[0].longitude, maxLon = coords[0].longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude); maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.005),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.005)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Bottom itinerary carousel

private struct PlannerMapStopCarousel: View {
    let stops: [ItineraryStop]
    @Binding var focusedStopID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 18)
            .allowsHitTesting(false)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(stops) { stop in
                        PlannerMapStopCarouselCard(
                            stop: stop,
                            itineraryStops: stops,
                            isFocused: focusedStopID == stop.id
                        )
                        .id(stop.id)
                    }
                }
                .padding(.horizontal, 20)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focusedStopID, anchor: .center)
            .frame(height: 96)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)
        }
    }
}

private struct PlannerMapStopCarouselCard: View {
    let stop: ItineraryStop
    let itineraryStops: [ItineraryStop]
    let isFocused: Bool

    private var badgeStyle: PlannerStopBadgeStyle {
        PlannerStopBadgeStyle.forStop(stop, in: itineraryStops)
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(badgeStyle.fill)
                    .frame(width: 32, height: 32)
                Text("\(stop.order)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Group {
                if let data = stop.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    badgeStyle.color.opacity(0.18)
                        .overlay {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(badgeStyle.color)
                        }
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(stop.placeName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(width: 268)
        .background(Color(.systemBackground).opacity(0.94), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(badgeStyle.color.opacity(isFocused ? 1 : 0.45), lineWidth: isFocused ? 2.5 : 1.5)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(badgeStyle.color)
                .frame(width: 4)
        }
        .shadow(color: BabyTownTheme.cardShadow, radius: isFocused ? 8 : 4, y: 2)
        .scaleEffect(isFocused ? 1.02 : 1)
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Stop marker

private struct PlannerStopMarkerView: View {
    let order: Int
    let badgeStyle: PlannerStopBadgeStyle
    let photoData: Data?
    let placeName: String

    private var trimmedPlaceName: String {
        placeName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Group {
                    if let data = photoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(badgeStyle.fill)
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(badgeStyle.color, lineWidth: 2.5)
                }

                Text("\(order)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }

            if !trimmedPlaceName.isEmpty {
                Text(trimmedPlaceName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black))
                    .frame(maxWidth: 110)
            }
        }
    }
}
