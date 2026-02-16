import SwiftUI

struct OnThisDayPhotoViewer: View {
    let photos: [Moment]
    let startIndex: Int
    let onDismiss: () -> Void
    let onAddMemory: (Moment) -> Void
    let viewModel: HomeViewModel
    
    @State private var currentIndex: Int
    @State private var offset: CGSize = .zero
    @State private var showAddedFeedback = false
    
    init(photos: [Moment], startIndex: Int, onDismiss: @escaping () -> Void, onAddMemory: @escaping (Moment) -> Void, viewModel: HomeViewModel) {
        self.photos = photos
        self.startIndex = startIndex
        self.onDismiss = onDismiss
        self.onAddMemory = onAddMemory
        self.viewModel = viewModel
        _currentIndex = State(initialValue: startIndex)
    }
    
    private var currentPhoto: Moment {
        photos[currentIndex]
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy • h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: currentPhoto.dateTaken)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Close button
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.black.opacity(0.5))
                            )
                    }
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                }
                
                Spacer()
                
                // Photo viewer with swipe
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        Image(uiImage: photo.thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                Spacer()
                
                // Photo info and Add Memory button
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text(dateString)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        
                        if let placeName = currentPhoto.placeName {
                            Text(placeName)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        // Page indicator
                        if photos.count > 1 {
                            Text("\(currentIndex + 1) / \(photos.count)")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(.top, 4)
                        }
                    }
                    
                    // Add Memory button
                    let isAlreadyAdded = viewModel.isAddedFromOnThisDay(currentPhoto)
                    let buttonText = isAlreadyAdded || showAddedFeedback ? "Added to Timeline!" : "Add Memory"
                    let buttonIcon = isAlreadyAdded || showAddedFeedback ? "checkmark.circle.fill" : "heart.fill"
                    
                    Button {
                        guard !isAlreadyAdded else { return }
                        onAddMemory(currentPhoto)
                        withAnimation(.spring(response: 0.3)) {
                            showAddedFeedback = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation {
                                showAddedFeedback = false
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: buttonIcon)
                                .font(.system(size: 16, weight: .semibold))
                            Text(buttonText)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(isAlreadyAdded || showAddedFeedback ? AnyShapeStyle(Color.green) : AnyShapeStyle(BabyTownTheme.accentGradient))
                        )
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
                    }
                    .disabled(isAlreadyAdded || showAddedFeedback)
                }
                .padding(.bottom, 40)
            }
        }
    }
}
