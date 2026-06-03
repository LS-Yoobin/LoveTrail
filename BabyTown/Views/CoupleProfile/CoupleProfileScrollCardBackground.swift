import SwiftUI

/// Dark glass card surface shared by Our History, Important Dates, and Pinned Memories.
struct CoupleProfileScrollCardBackground: View {
    var cornerRadius: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.black.opacity(0.45))
    }
}
