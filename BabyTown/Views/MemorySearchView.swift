import SwiftUI

struct MemorySearchView: View {
    
    @Environment(\.dismiss) private var dismiss
    let allMoments: [Moment]
    var onOpenPhoto: (Moment, [Moment]) -> Void
    var onEditCaption: (UUID, String, String?) -> Void
    var onRemove: (DaySection) -> Void
    var onTogglePin: (DaySection) -> Void
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    private var filteredSections: [DaySection] {
        if searchText.isEmpty {
            return []
        }
        
        let filtered = allMoments.filter { moment in
            matchesSearch(moment: moment, query: searchText)
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
            
            TextField("Search by month, year, or date...", text: $searchText)
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
                        onRemove: onRemove,
                        onTogglePin: onTogglePin,
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
            
            Text("Try searching by:\n• Month (e.g., \"January\", \"Jan\")\n• Year (e.g., \"2024\")\n• Date (e.g., \"15\", \"25th\")")
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
    
    private func matchesSearch(moment: Moment, query: String) -> Bool {
        let lowercaseQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        
        if lowercaseQuery.isEmpty {
            return false
        }
        
        let calendar = Calendar.current
        let date = moment.dateTaken
        
        // Extract date components
        let year = calendar.component(.year, from: date)
        let _ = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        // Month names
        let monthName = date.formatted(.dateTime.month(.wide)).lowercased()
        let monthAbbreviation = date.formatted(.dateTime.month(.abbreviated)).lowercased()
        
        // Check year match
        if String(year).contains(lowercaseQuery) {
            return true
        }
        
        // Check month name match
        if monthName.contains(lowercaseQuery) || monthAbbreviation.contains(lowercaseQuery) {
            return true
        }
        
        // Check day match
        let dayString = String(day)
        if dayString == lowercaseQuery || "\(day)th" == lowercaseQuery || "\(day)st" == lowercaseQuery || "\(day)nd" == lowercaseQuery || "\(day)rd" == lowercaseQuery {
            return true
        }
        
        // Check if query is just a number that matches the day
        if let queryNumber = Int(lowercaseQuery), queryNumber == day {
            return true
        }
        
        // Check full date string
        let fullDateString = date.formatted(.dateTime.month().day().year()).lowercased()
        if fullDateString.contains(lowercaseQuery) {
            return true
        }
        
        return false
    }
}

#Preview {
    MemorySearchView(
        allMoments: Moment.sampleMoments,
        onOpenPhoto: { _, _ in },
        onEditCaption: { _, _, _ in },
        onRemove: { _ in },
        onTogglePin: { _ in }
    )
}
