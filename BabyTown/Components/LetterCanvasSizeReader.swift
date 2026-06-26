import SwiftUI

/// Reads the letter card canvas size for overlay positioning.
/// Uses an outer `GeometryReader` so size matches the letter card even when
/// overlay children are positioned and do not contribute to layout.
struct LetterCanvasSizeReader<Content: View>: View {
    @ViewBuilder let content: (CGSize) -> Content

    var body: some View {
        GeometryReader { geo in
            content(geo.size)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
