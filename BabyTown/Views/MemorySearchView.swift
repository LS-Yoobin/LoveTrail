import SwiftUI

struct MemorySearchView: View {
    
    @Environment(\.dismiss) private var dismiss
    let allMoments: [Moment]
    var onOpenPhoto: (Moment, [Moment]) -> Void
    var onEditCaption: (UUID, String, String?) -> Void
    var onEditMemory: (DaySection, UUID, String, String?, Double?, Double?, Bool) -> Void
    var onRemove: (DaySection) -> Void
    var onTogglePin: (DaySection) -> Void
    var onShare: ((MemorySharePayload) -> Void)? = nil
    
    @State private var searchText = ""
    @StateObject private var shareCoordinator = MemoryShareCoordinator()
    @FocusState private var isSearchFocused: Bool
    
    private var filteredSections: [DaySection] {
        if searchText.isEmpty {
            return []
        }
        
        let filtered = allMoments.filter { moment in
            MemorySearchMatcher.matches(moment: moment, query: searchText)
        }
        
        return DaySection.grouped(from: filtered)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BabyTownTheme.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    searchBar
                    
                    if searchText.isEmpty {
                        emptySearchState
                    } else if filteredSections.isEmpty {
                        noResultsState
                    } else {
                        searchResults
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .memorySharePresentation(coordinator: shareCoordinator)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Search Memories")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                }
                
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.6))
                    }
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.5))
            
            TextField("Places, dates, love notes, prompts...", text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .focused($isSearchFocused)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var searchResults: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                ForEach(filteredSections) { section in
                    DayClusterCard(
                        section: section,
                        onOpenPhoto: onOpenPhoto,
                        onEditCaption: onEditCaption,
                        onEditMemory: onEditMemory,
                        onRemove: onRemove,
                        onTogglePin: onTogglePin,
                        onShare: { payload in
                            if let onShare {
                                onShare(payload)
                            } else {
                                shareCoordinator.share(payload)
                            }
                        },
                        isLeftAligned: true
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
    }
    
    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(BabyTownTheme.accent.opacity(0.3))
            
            Text("Search Your Memories")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textPrimary)
            
            Text("Try searching by place, date, love note, or prompt text.")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    private var noResultsState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundStyle(BabyTownTheme.textSecondary.opacity(0.5))
            
            Text("No Memories Found")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textPrimary)
            
            Text("Try a different search term")
                .font(.system(size: 14))
                .foregroundStyle(BabyTownTheme.textSecondary)
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    MemorySearchView(
        allMoments: Moment.sampleMoments,
        onOpenPhoto: { _, _ in },
        onEditCaption: { _, _, _ in },
        onEditMemory: { _, _, _, _, _, _, _ in },
        onRemove: { _ in },
        onTogglePin: { _ in }
    )
}
