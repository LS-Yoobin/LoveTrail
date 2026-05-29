import SwiftUI
import Photos
import MapKit
import CoreLocation

struct CaptionEditorSheet: View {
    
    let section: DaySection
    var onSave: (UUID, String, String?, Double?, Double?, Bool) -> Void
    var onAddPhotos: (([UIImage]) -> Void)?
    var onRemovePhoto: ((UUID) -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var captionText: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var showPhotoPicker = false
    @State private var selectedImages: [UIImage] = []
    
    // Location editing (fastblog-style flow)
    @State private var isEditingLocation = false
    @State private var editedPlaceName: String = ""
    @State private var isPlaceNameUserSet = false
    @State private var initialPlaceName: String = ""
    @State private var initialLatitude: Double?
    @State private var initialLongitude: Double?
    @State private var editedLatitude: Double?
    @State private var editedLongitude: Double?
    @State private var mapCenter: CLLocationCoordinate2D?
    @State private var mapSpanMeters: CLLocationDistance = 350
    @State private var mapShowsPin = true
    @State private var mapShowsUserLocation = false
    @State private var mapViewportHint: String?
    @State private var isMapBootstrapping = false
    @State private var isResolvingPOI = false
    @State private var showSuggestions = true
    @State private var showMapTapPOIDisambiguation = false
    @State private var mapTapPOICandidates: [MapTapPOICandidate] = []
    @FocusState private var isPlaceFieldFocused: Bool
    @StateObject private var placeSearch = MemoryPlaceSearchViewModel()
    
    private var mapCoordinate: CLLocationCoordinate2D? {
        if let lat = editedLatitude, let lon = editedLongitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return mapCenter
    }

    private var mapLocationBottomHint: String {
        if let mapViewportHint {
            return mapViewportHint
        }
        return "Tap a place on the map or search above"
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isEditingLocation {
                    locationEditingView
                } else {
                    mainEditingView
                }
            }
            .navigationTitle(isEditingLocation ? "Location" : "Edit Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditingLocation {
                        Button("Back") {
                            syncUserSetPlaceFlagFromEdits()
                            isEditingLocation = false
                            isPlaceFieldFocused = false
                            placeSearch.suggestions = []
                        }
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                
                if !isEditingLocation {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveMemory()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                captionText = section.moments.first?.caption ?? ""
                loadInitialPlaceState()
                isTextFieldFocused = true
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPickerView(selectedImages: $selectedImages, selectionLimit: 10)
                    .onDisappear {
                        if !selectedImages.isEmpty {
                            onAddPhotos?(selectedImages)
                            selectedImages = []
                        }
                    }
            }
            .sheet(isPresented: $showMapTapPOIDisambiguation) {
                poiDisambiguationSheet
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Main edit form
    
    private var mainEditingView: some View {
        ScrollView {
            VStack(spacing: 20) {
                locationSection
                photoManagementSection
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a love note for this memory")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                    
                    TextField("Type your caption here...", text: $captionText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray4))
                        )
                        .lineLimit(3...6)
                        .focused($isTextFieldFocused)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Location editing (map + autocomplete)
    
    private var locationEditingView: some View {
        ZStack(alignment: .bottom) {
            if let coord = mapCoordinate {
                MemoryLocationMapView(
                    center: coord,
                    title: editedPlaceName.isEmpty ? nil : editedPlaceName,
                    spanMeters: mapSpanMeters,
                    showsPin: mapShowsPin,
                    showsUserLocation: mapShowsUserLocation,
                    onTap: { tapped, region in
                        resolvePOI(at: tapped, mapRegion: region)
                    },
                    onMapFeatureTap: { feature, region, endSelection in
                        resolvePOIFromMapFeature(feature, mapRegion: region, endMapSelection: endSelection)
                    }
                )
                .ignoresSafeArea(edges: .bottom)
            }

            if isMapBootstrapping {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .overlay {
                        ProgressView()
                            .tint(BabyTownTheme.accent)
                    }
            }
            
            if isResolvingPOI {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        ProgressView()
                            .tint(.white)
                    }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            locationTopInset
        }
        .overlay(alignment: .bottom) {
            Text(mapLocationBottomHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 12)
        }
        .task(id: isEditingLocation) {
            guard isEditingLocation else { return }
            await bootstrapMapCenter()
        }
    }
    
    private static let foundingPrompts: Set<String> = [
        "When we first met",
        "When we became official"
    ]

    private var foundingPromptText: String? {
        guard let prompt = section.moments.first?.promptText,
              Self.foundingPrompts.contains(prompt) else { return nil }
        return prompt
    }

    private var locationTopInset: some View {
        VStack(spacing: 0) {
            if let foundingPromptText {
                PromptDisplayCard(prompt: foundingPromptText, variant: .formHeader)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Place name", text: $editedPlaceName)
                    .focused($isPlaceFieldFocused)
                    .autocorrectionDisabled()
                    .onChange(of: isPlaceFieldFocused) { _, focused in
                        if focused {
                            showSuggestions = true
                            placeSearch.query = editedPlaceName
                        }
                    }
                    .onChange(of: editedPlaceName) { _, newValue in
                        if showSuggestions {
                            placeSearch.query = newValue
                        }
                    }
                
                if !editedPlaceName.isEmpty {
                    Button {
                        editedPlaceName = ""
                        placeSearch.query = ""
                        isPlaceFieldFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray4))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            if isPlaceFieldFocused, showSuggestions, !placeSearch.suggestions.isEmpty {
                suggestionsList
            }
        }
    }
    
    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            Text("Suggestions")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(placeSearch.suggestions) { suggestion in
                        Button {
                            applyAutocompleteSuggestion(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                if !suggestion.subtitle.isEmpty {
                                    Text(suggestion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .background(Color(.systemBackground))
    }
    
    private var poiDisambiguationSheet: some View {
        NavigationStack {
            List(mapTapPOICandidates) { candidate in
                Button {
                    applyMapTapPOIChoice(candidate)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(candidate.name)
                            .font(.body.weight(.medium))
                        Text(
                            candidate.distanceMeters < 8
                                ? "Very near your tap"
                                : String(format: "About %.0f m from your tap", candidate.distanceMeters)
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Which place is this?")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private var locationSection: some View {
        Button {
            isEditingLocation = true
            isTextFieldFocused = false
            primeMapForLocationEditingIfNeeded()
            placeSearch.setBiasLocation(mapCoordinate)
            placeSearch.query = editedPlaceName
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(BabyTownTheme.accent)
                    Text("Location")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                locationDisplayRow
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray4))
                    )
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
    
    @ViewBuilder
    private var locationDisplayRow: some View {
        let trimmed = editedPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            Text("Tap to add a location")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.9))
        } else {
            PlaceNameLabel(
                rawPlaceName: trimmed,
                isUserSet: isPlaceNameUserSet,
                font: .system(size: 15),
                foregroundStyle: .white.opacity(0.9),
                iconSize: 13,
                spacing: 5,
                lineLimit: 2
            )
        }
    }
    
    private var photoManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 14))
                    .foregroundStyle(BabyTownTheme.accent)
                Text("Photos in this Memory")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(section.moments.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accent)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(section.moments) { moment in
                        photoThumbnail(moment)
                    }
                    
                    addPhotoButton
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func photoThumbnail(_ moment: Moment) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: moment.thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            if section.moments.count > 1 {
                Button {
                    onRemovePhoto?(moment.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .background(
                            Circle()
                                .fill(.black.opacity(0.5))
                                .frame(width: 20, height: 20)
                        )
                }
                .padding(.top, 5)
                .padding(.trailing, 5)
            }
        }
    }
    
    private var addPhotoButton: some View {
        Button {
            showPhotoPicker = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                Text("Add")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(BabyTownTheme.accent)
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(BabyTownTheme.accent, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(BabyTownTheme.accent.opacity(0.1))
                    )
            )
        }
    }
    
    // MARK: - Place state
    
    private func loadInitialPlaceState() {
        let raw = section.moments.first?.placeName ?? ""
        editedPlaceName = PlaceNameFormatting.storedName(fromUserInput: raw)
        isPlaceNameUserSet = section.moments.first?.isPlaceNameUserSet ?? false
        initialPlaceName = editedPlaceName
        editedLatitude = section.moments.first?.latitude
        editedLongitude = section.moments.first?.longitude
        initialLatitude = editedLatitude
        initialLongitude = editedLongitude
        if let lat = editedLatitude, let lon = editedLongitude {
            mapCenter = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            mapSpanMeters = 350
            mapShowsPin = true
            mapShowsUserLocation = false
            mapViewportHint = nil
        }
    }
    
    private func primeMapForLocationEditingIfNeeded() {
        guard mapCoordinate == nil else { return }
        let regional = MapRegionalDefault.coordinate()
        mapCenter = regional
        mapSpanMeters = MapRegionalDefault.spanMeters
        mapShowsPin = false
        mapShowsUserLocation = false
        mapViewportHint = MapBootstrapResult.viewportRegional(regional).viewportHint
    }

    private func bootstrapMapCenter() async {
        await MainActor.run { isMapBootstrapping = true }
        let result = await resolveMapBootstrap()
        await MainActor.run {
            applyMapBootstrapResult(result)
            isMapBootstrapping = false
        }
    }

    private func applyMapBootstrapResult(_ result: MapBootstrapResult) {
        mapCenter = result.coordinate
        mapSpanMeters = result.spanMeters
        mapShowsPin = result.showsPin
        mapShowsUserLocation = result.showsUserLocation
        mapViewportHint = result.viewportHint
        placeSearch.setBiasLocation(result.coordinate)

        if case .memoryOrPhoto(_, let prefill) = result, prefill {
            editedLatitude = result.coordinate.latitude
            editedLongitude = result.coordinate.longitude
        }
    }

    private func resolveMapBootstrap() async -> MapBootstrapResult {
        if let lat = editedLatitude, let lon = editedLongitude {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            return .memoryOrPhoto(coord, prefillCoordinates: false)
        }

        if let coord = photoGPSCoordinate() {
            return .memoryOrPhoto(coord, prefillCoordinates: true)
        }

        if let deviceCoord = await MapBootstrapLocationProvider.currentCoordinate() {
            return .viewportDevice(deviceCoord)
        }

        let regional = MapRegionalDefault.coordinate()
        return .viewportRegional(regional)
    }

    private func photoGPSCoordinate() -> CLLocationCoordinate2D? {
        if let assetId = section.moments.first?.assetIdentifier {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            if let asset = assets.firstObject, let location = asset.location {
                return location.coordinate
            }
        }
        for moment in section.moments {
            if let assetId = moment.assetIdentifier {
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                if let asset = assets.firstObject, let location = asset.location {
                    return location.coordinate
                }
            }
        }
        return nil
    }
    
    private func markUserSetPlace() {
        isPlaceNameUserSet = true
    }

    private func syncUserSetPlaceFlagFromEdits() {
        let trimmed = editedPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeChanged = trimmed != initialPlaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let coordinatesChanged = editedLatitude != initialLatitude || editedLongitude != initialLongitude
        if placeChanged || coordinatesChanged {
            markUserSetPlace()
        }
    }

    // MARK: - POI resolution
    
    private func applyAutocompleteSuggestion(_ suggestion: PlaceSuggestion) {
        markUserSetPlace()
        showSuggestions = false
        isPlaceFieldFocused = false
        editedPlaceName = suggestion.title
        placeSearch.suggestions = []
        Task { @MainActor in
            if let coord = await placeSearch.resolveDetails(for: suggestion) {
                editedLatitude = coord.latitude
                editedLongitude = coord.longitude
                mapCenter = coord
                mapSpanMeters = 350
                mapShowsPin = true
                mapShowsUserLocation = false
                mapViewportHint = nil
                placeSearch.setBiasLocation(coord)
            }
        }
    }
    
    private func applyMapTapPOIChoice(_ candidate: MapTapPOICandidate) {
        markUserSetPlace()
        editedPlaceName = candidate.name
        editedLatitude = candidate.coordinate.latitude
        editedLongitude = candidate.coordinate.longitude
        mapCenter = candidate.coordinate
        mapSpanMeters = 350
        mapShowsPin = true
        mapShowsUserLocation = false
        mapViewportHint = nil
        showMapTapPOIDisambiguation = false
        mapTapPOICandidates = []
    }
    
    private func resolvePOI(at coordinate: CLLocationCoordinate2D, mapRegion: MKCoordinateRegion?) {
        guard !isResolvingPOI else { return }
        isResolvingPOI = true
        isPlaceFieldFocused = false
        showSuggestions = false
        editedLatitude = coordinate.latitude
        editedLongitude = coordinate.longitude
        mapCenter = coordinate
        mapSpanMeters = 350
        mapShowsPin = true
        mapShowsUserLocation = false
        mapViewportHint = nil
        
        Task { @MainActor in
            defer { isResolvingPOI = false }
            switch await placeSearch.resolveMapTapPOI(near: coordinate, mapRegion: mapRegion) {
            case .single(let name, let coord):
                markUserSetPlace()
                editedPlaceName = name
                editedLatitude = coord.latitude
                editedLongitude = coord.longitude
                mapCenter = coord
                mapSpanMeters = 350
                mapShowsPin = true
                mapShowsUserLocation = false
                mapViewportHint = nil
            case .ambiguous(let candidates):
                mapTapPOICandidates = candidates
                showMapTapPOIDisambiguation = true
            case .none:
                let name = await placeSearch.resolveCoordinateName(at: coordinate)
                if !name.isEmpty, name != "Unknown Place" {
                    markUserSetPlace()
                    editedPlaceName = name
                }
            }
        }
    }
    
    private func resolvePOIFromMapFeature(
        _ annotation: MKMapFeatureAnnotation,
        mapRegion: MKCoordinateRegion,
        endMapSelection: @escaping () -> Void
    ) {
        guard !isResolvingPOI else {
            endMapSelection()
            return
        }
        isResolvingPOI = true
        isPlaceFieldFocused = false
        showSuggestions = false
        
        Task { @MainActor in
            defer {
                isResolvingPOI = false
                endMapSelection()
            }
            let request = MKMapItemRequest(mapFeatureAnnotation: annotation)
            if let mapItem = try? await request.mapItem,
               let raw = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines),
               !raw.isEmpty {
                markUserSetPlace()
                editedPlaceName = raw
                let coord = mapItem.placemark.coordinate
                editedLatitude = coord.latitude
                editedLongitude = coord.longitude
                mapCenter = coord
                mapSpanMeters = 350
                mapShowsPin = true
                mapShowsUserLocation = false
                mapViewportHint = nil
                return
            }
            let titlePart = annotation.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitlePart = annotation.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines)
            let combined = [titlePart, subtitlePart].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")
            if !combined.isEmpty {
                markUserSetPlace()
                editedPlaceName = combined
                editedLatitude = annotation.coordinate.latitude
                editedLongitude = annotation.coordinate.longitude
                mapCenter = annotation.coordinate
                mapSpanMeters = 350
                mapShowsPin = true
                mapShowsUserLocation = false
                mapViewportHint = nil
                return
            }
            resolvePOI(at: annotation.coordinate, mapRegion: mapRegion)
        }
    }
    
    private func saveMemory() {
        guard let firstMoment = section.moments.first else { return }
        syncUserSetPlaceFlagFromEdits()
        let trimmedPlace = PlaceNameFormatting.storedName(fromUserInput: editedPlaceName)
        let placeName = trimmedPlace.isEmpty ? nil : trimmedPlace
        onSave(firstMoment.id, captionText, placeName, editedLatitude, editedLongitude, isPlaceNameUserSet)
        dismiss()
    }
}
