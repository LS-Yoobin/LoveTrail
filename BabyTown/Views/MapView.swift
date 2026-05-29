import SwiftUI
import MapKit

struct POISelection: Identifiable {
    let id = UUID()
    let title: String
    let coordinate: CLLocationCoordinate2D
}

struct MapView: View {
    @ObservedObject var viewModel: HomeViewModel
    let onOpenMemory: (DaySection) -> Void
    let onDismiss: () -> Void
    let onScanPhotos: () -> Void
    
    @State private var selectedYear: Int
    @State private var availableYears: [Int] = []
    @State private var region: MKCoordinateRegion
    @State private var annotations: [MemoryMapAnnotation] = []
    @State private var showEmptyStatePrompt = true
    @State private var poiSelection: POISelection?
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var selectedCountry: String?
    
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
        
        // Initialize with "All" (0)
        _selectedYear = State(initialValue: 0)
        
        // Initialize with default region
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        ))
    }
    
    var body: some View {
        ZStack {
            // New Map Component
            MemoryMapView(
                region: $region,
                annotations: annotations,
                onSelect: { section in
                    onOpenMemory(section)
                },
                onSelectPOI: { title, coordinate in
                    poiSelection = POISelection(title: title, coordinate: coordinate)
                }
            )
            .ignoresSafeArea()
            
            // Top controls (map visible behind)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Button {
                        onDismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white)
                                .frame(width: 44, height: 44)
                                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.black)
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isSearchActive.toggle() }
                        if !isSearchActive {
                            searchText = ""
                            updateAnnotations()
                        }
                    } label: {
                        mapCircleIcon(isSearchActive ? "xmark" : "magnifyingglass", filled: isSearchActive)
                    }

                    Menu {
                        Button("All Countries") {
                            selectedCountry = nil
                            updateAnnotations()
                            centerMapOnMemories()
                        }
                        ForEach(viewModel.availableCountries, id: \.self) { country in
                            Button(country) {
                                selectedCountry = country
                                updateAnnotations()
                                centerMapOnMemories()
                            }
                        }
                    } label: {
                        mapCircleIcon(
                            selectedCountry == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill",
                            filled: selectedCountry != nil
                        )
                    }
                }

                if isSearchActive {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.black.opacity(0.5))
                        TextField("Search place, country, or date", text: $searchText)
                            .foregroundStyle(.black)
                            .autocorrectionDisabled()
                            .onChange(of: searchText) { _, _ in updateAnnotations() }
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                updateAnnotations()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.black.opacity(0.3))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    )
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
                                        centerMapOnMemories()
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
            
            // Empty state
            if annotations.isEmpty && showEmptyStatePrompt {
                MapEmptyStateView(
                    selectedYear: selectedYear,
                    onScanPhotos: {
                        onScanPhotos()
                    },
                    onDismiss: {
                        showEmptyStatePrompt = false
                    }
                )
            }
            
        }
        .onAppear {
            setupMapData()
            showEmptyStatePrompt = true
            viewModel.backfillCountriesIfNeeded()
        }
        .sheet(item: $poiSelection) { selection in
            POIInfoSheet(placeName: selection.title, coordinate: selection.coordinate)
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

    private func setupMapData() {
        // Get available years and add "All"
        var years = viewModel.availableYears()
        if !years.isEmpty {
            years.insert(0, at: 0)
        }
        availableYears = years
        
        // Update annotations and center map
        updateAnnotations()
        centerMapOnMemories()
    }
    
    private func updateAnnotations() {
        let base: [DaySection]
        if selectedYear == 0 {
            base = viewModel.memoriesWithLocation()
        } else {
            base = viewModel.memories(forYear: selectedYear)
        }

        let filtered = base.filter { section in
            matchesCountry(section) && matchesSearch(section)
        }
        annotations = filtered.map { MemoryMapAnnotation(section: $0) }
    }

    private func matchesCountry(_ section: DaySection) -> Bool {
        guard let selectedCountry else { return true }
        return section.moments.contains { $0.country == selectedCountry }
    }

    private func matchesSearch(_ section: DaySection) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        let place = section.placeDisplay.lowercased()
        let country = section.moments.compactMap { $0.country }.joined(separator: " ").lowercased()
        let date = section.timeDisplay.lowercased()
        return place.contains(query) || country.contains(query) || date.contains(query)
    }
    
    private func centerMapOnMemories() {
        guard !annotations.isEmpty else { return }
        
        let coordinates = annotations.map { $0.coordinate }
        
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0
        
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        
        let spanLat = (maxLat - minLat) * 1.5
        let spanLon = (maxLon - minLon) * 1.5
        
        let finalSpanLat = max(spanLat, 0.05)
        let finalSpanLon = max(spanLon, 0.05)
        
        // For "All" view, maybe use a slightly larger padding if there are many memories
        let padding = selectedYear == 0 ? 2.0 : 1.5
        let paddedSpanLat = max(spanLat * padding, 0.05)
        let paddedSpanLon = max(spanLon * padding, 0.05)
        
        withAnimation(.easeInOut(duration: 0.5)) {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: paddedSpanLat, longitudeDelta: paddedSpanLon)
            )
        }
    }

}

#Preview {
    let viewModel = HomeViewModel.filledPreview
    return MapView(viewModel: viewModel, onOpenMemory: { _ in }, onDismiss: {
        print("Dismiss")
    }, onScanPhotos: {
        print("Scan photos")
    })
}
