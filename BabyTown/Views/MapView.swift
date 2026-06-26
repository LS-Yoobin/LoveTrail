import SwiftUI
import MapKit

struct MapView: View {

    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject private var store: StoreManager = .shared
    let onOpenMemory: (DaySection) -> Void
    let onDismiss: () -> Void
    let onScanPhotos: () -> Void

    @State private var selectedYear: Int
    @State private var showVaultedPrompt = false
    @State private var showForeverPaywall = false
    @State private var availableYears: [Int] = []
    @State private var region: MKCoordinateRegion
    @State private var annotations: [MemoryMapAnnotation] = []
    @State private var showEmptyStatePrompt = true
    @State private var poiSelection: POISelection?
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var selectedCountry: String?
    @FocusState private var isSearchFocused: Bool
    @State private var annotationUpdateTask: Task<Void, Never>?
    @State private var mapSetupTask: Task<Void, Never>?
    @State private var isLoadingMapData = true

    private let photoPinThumbnailLimit = 60
    private let minMapSpan: CLLocationDegrees = 0.001
    private let maxMapSpan: CLLocationDegrees = 80
    private let userLocationSpan: CLLocationDegrees = 0.02

    init(
        viewModel: HomeViewModel,
        onOpenMemory: @escaping (DaySection) -> Void,
        onDismiss: @escaping () -> Void,
        onScanPhotos: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onOpenMemory = onOpenMemory
        self.onDismiss = onDismiss
        self.onScanPhotos = onScanPhotos
        _selectedYear = State(initialValue: 0)
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        ))
    }

    private var filteredSections: [DaySection] {
        MapPlacesFiltering.sections(
            from: viewModel,
            selectedYear: selectedYear,
            selectedCountry: selectedCountry,
            searchText: searchText
        )
    }

    /// Located memories for search, newest first.
    private var searchResultSections: [DaySection] {
        filteredSections.sorted { $0.timelineSortDate > $1.timelineSortDate }
    }

    var body: some View {
        ZStack {
            if isSearchActive {
                mapSearchResultsView
                    .transition(.opacity)
            } else {
                mapContentView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearchActive)
        .onAppear {
            showEmptyStatePrompt = true
            mapSetupTask?.cancel()
            mapSetupTask = Task { @MainActor in
                await Task.yield()
                guard !Task.isCancelled else { return }
                await setupMapData()
            }
            Task {
                try? await Task.sleep(for: .seconds(2))
                viewModel.backfillCountriesIfNeeded()
            }
        }
        .onDisappear {
            mapSetupTask?.cancel()
            annotationUpdateTask?.cancel()
        }
        .sheet(item: $poiSelection) { selection in
            POIInfoSheet(placeName: selection.title, coordinate: selection.coordinate)
        }
        .sheet(isPresented: $showVaultedPrompt) {
            VaultedMomentPrompt(
                isPresented: $showVaultedPrompt,
                onUnlockForever: { showForeverPaywall = true }
            )
            .presentationDetents([.height(460)])
            .presentationDragIndicator(.visible)
            .presentationBackground(BabyTownTheme.cardBackground)
        }
        .fullScreenCover(isPresented: $showForeverPaywall) {
            CovelaForeverPaywallView(
                store: store,
                onUnlock: { showForeverPaywall = false },
                onDismiss: { showForeverPaywall = false }
            )
        }
    }

    // MARK: - Map (original full-screen experience)

    private var mapContentView: some View {
        ZStack {
            MemoryMapView(
                region: $region,
                annotations: annotations,
                onSelect: { section in
                    handleAnnotationTap(section)
                },
                onSelectPOI: { title, coordinate in
                    poiSelection = POISelection(title: title, coordinate: coordinate)
                }
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Button {
                        onDismiss()
                    } label: {
                        mapCircleIcon("chevron.left", filled: false)
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearchActive = true
                        }
                    } label: {
                        mapCircleIcon("magnifyingglass", filled: false)
                    }

                    Menu {
                        Button("All Countries") {
                            selectedCountry = nil
                            updateAnnotations()
                            // Keep the current zoom so grouped markers stay clustered;
                            // they only re-evaluate when the user zooms (matches search flow).
                        }
                        ForEach(viewModel.availableCountries, id: \.self) { country in
                            Button(country) {
                                selectedCountry = country
                                updateAnnotations()
                                // Keep the current zoom so grouped markers stay clustered;
                                // they only re-evaluate when the user zooms (matches search flow).
                            }
                        }
                    } label: {
                        mapCircleIcon(
                            selectedCountry == nil
                                ? "line.3.horizontal.decrease.circle"
                                : "line.3.horizontal.decrease.circle.fill",
                            filled: selectedCountry != nil
                        )
                    }
                }

                if !availableYears.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(availableYears, id: \.self) { year in
                                YearFilterChip(
                                    title: year == 0 ? "All" : String(year),
                                    isSelected: year == selectedYear
                                ) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        selectedYear = year
                                        updateAnnotations()
                                        // Keep the current zoom so grouped markers stay clustered;
                                        // they only re-evaluate when the user zooms (matches search flow).
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.45), Color.black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
                .ignoresSafeArea()
            )

            if isLoadingMapData {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !isLoadingMapData && annotations.isEmpty && showEmptyStatePrompt {
                MapEmptyStateView(
                    selectedYear: selectedYear,
                    onScanPhotos: onScanPhotos,
                    onDismiss: { showEmptyStatePrompt = false }
                )
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    mapControlsStack
                }
            }
            .padding(.trailing, 16)
            .padding(.bottom, 24)
        }
    }

    private var mapControlsStack: some View {
        VStack(spacing: 10) {
            Button {
                zoomMap(spanMultiplier: 0.5)
            } label: {
                mapCircleIcon("plus", filled: false)
            }

            Button {
                zoomMap(spanMultiplier: 2)
            } label: {
                mapCircleIcon("minus", filled: false)
            }

            Button {
                Task { await centerOnUserLocation() }
            } label: {
                mapCircleIcon("location.fill", filled: true)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search results (gray list)

    private var mapSearchResultsView: some View {
        VStack(spacing: 0) {
            mapSearchTopBar

            ScrollView(showsIndicators: false) {
                if searchResultSections.isEmpty {
                    mapSearchEmptyState
                        .padding(.top, 48)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(searchResultSections) { section in
                            MapPlaceMemoryCard(section: section) {
                                openMemoryFromSearch(section)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6).ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
    }

    private var mapSearchTopBar: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    closeSearch()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.35))
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(BabyTownTheme.textSecondary)

                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("Search place, country, or date")
                        .foregroundStyle(BabyTownTheme.textTertiary)
                )
                .font(.system(size: 16))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .onChange(of: searchText) { _, _ in
                    scheduleAnnotationUpdate()
                }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        updateAnnotations()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(BabyTownTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemGray6))
    }

    private var mapSearchEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 40))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.35))

            Text(searchText.isEmpty ? "No places yet" : "No matches")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textPrimary)

            Text(
                searchText.isEmpty
                    ? "Add location to your memories to see them here."
                    : "Try a different search term or clear filters on the map."
            )
            .font(.system(size: 14))
            .foregroundStyle(BabyTownTheme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func closeSearch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearchActive = false
            isSearchFocused = false
            searchText = ""
            updateAnnotations()
        }
    }

    private func openMemoryFromSearch(_ section: DaySection) {
        isSearchFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        onOpenMemory(section)
    }

    private func handleAnnotationTap(_ section: DaySection) {
        let vaulted = viewModel.vaultedMomentIDs(isForeverUnlocked: store.isForeverUnlocked)
        if section.moments.contains(where: { vaulted.contains($0.id) }) {
            showVaultedPrompt = true
        } else {
            onOpenMemory(section)
        }
    }

    private func mapCircleIcon(_ systemName: String, filled: Bool) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 44, height: 44)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(filled ? BabyTownTheme.accent : .black)
        }
    }

    private func setupMapData() async {
        isLoadingMapData = true
        defer { isLoadingMapData = false }

        var years = viewModel.availableYears()
        if !years.isEmpty {
            years.insert(0, at: 0)
        }
        availableYears = years

        let sections = filteredSections
        let showsPhotoThumbnails = sections.count <= photoPinThumbnailLimit
        let vaulted = viewModel.vaultedMomentIDs(isForeverUnlocked: store.isForeverUnlocked)
        var built: [MemoryMapAnnotation] = []
        built.reserveCapacity(sections.count)

        let batchSize = 50
        for start in stride(from: 0, to: sections.count, by: batchSize) {
            guard !Task.isCancelled else { return }
            let end = min(start + batchSize, sections.count)
            for section in sections[start..<end] {
                built.append(
                    MemoryMapAnnotation(
                        section: section,
                        showsPhotoThumbnail: showsPhotoThumbnails,
                        isVaulted: section.moments.contains { vaulted.contains($0.id) }
                    )
                )
            }
            annotations = built
            await Task.yield()
        }

        centerMapOnMemories()
    }

    private func updateAnnotations() {
        let sections = filteredSections
        let showsPhotoThumbnails = sections.count <= photoPinThumbnailLimit
        let vaulted = viewModel.vaultedMomentIDs(isForeverUnlocked: store.isForeverUnlocked)
        annotations = sections.map {
            MemoryMapAnnotation(
                section: $0,
                showsPhotoThumbnail: showsPhotoThumbnails,
                isVaulted: $0.moments.contains { vaulted.contains($0.id) }
            )
        }
    }

    private func scheduleAnnotationUpdate() {
        annotationUpdateTask?.cancel()
        annotationUpdateTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            updateAnnotations()
        }
    }

    private func zoomMap(spanMultiplier: Double) {
        let newLat = min(max(region.span.latitudeDelta * spanMultiplier, minMapSpan), maxMapSpan)
        let newLon = min(max(region.span.longitudeDelta * spanMultiplier, minMapSpan), maxMapSpan)
        withAnimation(.easeInOut(duration: 0.25)) {
            region = MKCoordinateRegion(
                center: region.center,
                span: MKCoordinateSpan(latitudeDelta: newLat, longitudeDelta: newLon)
            )
        }
    }

    private func centerOnUserLocation() async {
        guard let coordinate = await MapBootstrapLocationProvider.currentCoordinate() else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: userLocationSpan, longitudeDelta: userLocationSpan)
            )
        }
    }

    /// How many of the newest places to consider when framing the map.
    private let recentPlaceWindow = 12
    /// Recent places farther than this from the newest one (in degrees lat/lon) are
    /// treated as a separate trip and excluded, so an old/far outlier can't widen the view.
    private let recentPlaceClusterDegrees: CLLocationDegrees = 1.5

    /// Frames the map around the *latest* places rather than the geographic midpoint of
    /// every memory. Anchors on the newest place and includes only recent places near it.
    private func centerMapOnMemories() {
        guard !annotations.isEmpty else { return }

        let newestFirst = annotations.sorted {
            $0.section.timelineSortDate > $1.section.timelineSortDate
        }
        guard let anchor = newestFirst.first?.coordinate else { return }

        let nearbyRecent = newestFirst.prefix(recentPlaceWindow)
            .map(\.coordinate)
            .filter {
                abs($0.latitude - anchor.latitude) <= recentPlaceClusterDegrees
                    && abs($0.longitude - anchor.longitude) <= recentPlaceClusterDegrees
            }
        let coordinates = nearbyRecent.isEmpty ? [anchor] : nearbyRecent

        guard let fitted = coordinateRegion(
            fitting: coordinates,
            paddingFactor: 1.5,
            minimumSpan: 0.08,
            maximumLatitudeSpan: maxMapSpan,
            maximumLongitudeSpan: 360
        ) else { return }

        region = fitted
    }
}

#Preview {
    MapView(
        viewModel: HomeViewModel.filledPreview,
        onOpenMemory: { _ in },
        onDismiss: {},
        onScanPhotos: {}
    )
}
