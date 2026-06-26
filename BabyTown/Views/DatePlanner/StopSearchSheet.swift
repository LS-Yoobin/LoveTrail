import SwiftUI
import MapKit

struct StopSearchSheet: View {
    let onAdd: (ItineraryStop) -> Void
    let nextOrder: Int
    var assignDay: Int = 1

    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchVM = PlannerPlaceSearchViewModel()
    @State private var selectedTab: SearchTab = .moments
    @State private var momentQuery = ""
    @State private var webSource: WebPlaceSource?

    private enum SearchTab { case moments, web, places }

    private var filteredMoments: [Moment] {
        DataPersistenceManager.shared.loadMoments()
            .filter { $0.placeName != nil && $0.latitude != nil && $0.longitude != nil }
            .filter { moment in
                guard !momentQuery.isEmpty else { return true }
                return moment.placeName?.localizedCaseInsensitiveContains(momentQuery) == true
            }
            .sorted { $0.dateTaken > $1.dateTaken }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                tabPicker
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                Divider()

                if selectedTab == .places {
                    placesTab
                } else if selectedTab == .moments {
                    momentsTab
                } else {
                    webTab
                }
            }
            .navigationTitle("Add a stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton("Our Moments", tab: .moments)
            tabButton("Web", tab: .web)
            tabButton("Search", tab: .places)
        }
        .background(BabyTownTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
    }

    private func tabButton(_ title: String, tab: SearchTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selectedTab == tab ? .white : BabyTownTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == tab ? AnyShapeStyle(BabyTownTheme.accentGradient) : AnyShapeStyle(Color.clear),
                             in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .padding(2)
    }

    // MARK: - Places tab

    private var placesTab: some View {
        VStack(spacing: 0) {
            searchBar(text: $searchVM.query, placeholder: "Search for a restaurant, park, cinema")
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            if searchVM.suggestions.isEmpty && searchVM.query.isEmpty {
                ContentUnavailableView(
                    "Search for a place",
                    systemImage: "magnifyingglass",
                    description: Text("Restaurant, park, cinema and more")
                )
            } else if searchVM.suggestions.isEmpty {
                ContentUnavailableView(
                    "No results",
                    systemImage: "mappin.slash",
                    description: Text("Try a different search")
                )
            } else {
                List(searchVM.suggestions) { suggestion in
                    Button {
                        Task { await addPlaceSuggestion(suggestion) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.body)
                                .foregroundStyle(BabyTownTheme.textPrimary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(BabyTownTheme.textSecondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Our Moments tab

    private var momentsTab: some View {
        VStack(spacing: 0) {
            searchBar(text: $momentQuery, placeholder: "Search by place name")
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            if filteredMoments.isEmpty {
                ContentUnavailableView(
                    "No moments with a location",
                    systemImage: "photo.on.rectangle",
                    description: Text("Moments with a saved location will appear here")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(filteredMoments) { moment in
                            Button {
                                addMomentStop(moment)
                            } label: {
                                momentCell(moment)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func momentCell(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(uiImage: moment.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .bottomLeading) {
                    if let place = moment.placeName {
                        Text(place)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.65)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }

            Text(moment.dateTaken, style: .date)
                .font(.caption2)
                .foregroundStyle(BabyTownTheme.textSecondary)
        }
    }

    // MARK: - Web tab

    private var webTab: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.7))

            VStack(spacing: 8) {
                Text("Browse and add a place")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Open Google Maps or Yelp to find a spot, then tap the Add button when you land on a place page.")
                    .font(.subheadline)
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                webSourceButton("Google Maps", systemImage: "map.fill", source: .googleMaps)
                webSourceButton("Yelp", systemImage: "fork.knife", source: .yelp)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .fullScreenCover(item: $webSource) { source in
            WebPlaceBrowserView(
                source: source,
                onAdd: { stop in
                    onAdd(stop)
                    webSource = nil
                    DispatchQueue.main.async {
                        dismiss()
                    }
                },
                nextOrder: nextOrder,
                assignDay: assignDay
            )
        }
    }

    private func webSourceButton(_ title: String, systemImage: String, source: WebPlaceSource) -> some View {
        Button {
            webSource = source
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(BabyTownTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(BabyTownTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared search bar

    private func searchBar(text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(BabyTownTheme.textSecondary)
            TextField(placeholder, text: text)
                .font(.body)
        }
        .padding(10)
        .background(BabyTownTheme.accentSoft, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private func addPlaceSuggestion(_ suggestion: PlaceSuggestion) async {
        let coord = await searchVM.resolveDetails(for: suggestion)
        let stop = ItineraryStop(
            id: UUID(),
            order: nextOrder,
            day: assignDay,
            placeName: suggestion.title,
            address: suggestion.subtitle.isEmpty ? nil : suggestion.subtitle,
            latitude: coord?.latitude,
            longitude: coord?.longitude,
            momentID: nil,
            photoData: nil,
            note: nil
        )
        await MainActor.run {
            onAdd(stop)
            dismiss()
        }
    }

    private func addMomentStop(_ moment: Moment) {
        let photoData = moment.thumbnail.jpegData(compressionQuality: 0.6)
        let stop = ItineraryStop(
            id: UUID(),
            order: nextOrder,
            day: assignDay,
            placeName: moment.placeName ?? "",
            latitude: moment.latitude,
            longitude: moment.longitude,
            momentID: moment.id,
            photoData: photoData,
            note: moment.caption
        )
        onAdd(stop)
        dismiss()
    }
}
