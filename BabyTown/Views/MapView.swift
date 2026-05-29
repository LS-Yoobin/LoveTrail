import SwiftUI
import MapKit

struct MapView: View {
    @ObservedObject var viewModel: HomeViewModel
    let onOpenMemory: (DaySection) -> Void
    let onDismiss: () -> Void
    let onScanPhotos: () -> Void
    
    @State private var selectedYear: Int
    @State private var availableYears: [Int] = []
    @State private var selectedMemory: DaySection?
    @State private var showBottomSheet = false
    @State private var region: MKCoordinateRegion
    @State private var annotations: [MemoryMapAnnotation] = []
    @State private var showEmptyStatePrompt = true
    
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
                    selectedMemory = section
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showBottomSheet = true
                    }
                }
            )
            .ignoresSafeArea()
            
            // Top controls (map visible behind)
            VStack(alignment: .leading, spacing: 12) {
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
            
            // Bottom sheet
            if showBottomSheet, let memory = selectedMemory {
                VStack {
                    Spacer()
                    
                    MemoryBottomSheet(
                        section: memory,
                        onOpenMemory: {
                            showBottomSheet = false
                            onOpenMemory(memory)
                        },
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showBottomSheet = false
                            }
                        }
                    )
                    .transition(.move(edge: .bottom))
                }
                .background(
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showBottomSheet = false
                            }
                        }
                )
            }
        }
        .onAppear {
            setupMapData()
            showEmptyStatePrompt = true
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
        let memories: [DaySection]
        if selectedYear == 0 {
            memories = viewModel.memoriesWithLocation()
        } else {
            memories = viewModel.memories(forYear: selectedYear)
        }
        annotations = memories.map { MemoryMapAnnotation(section: $0) }
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
