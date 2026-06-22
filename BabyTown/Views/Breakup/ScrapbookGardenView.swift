import SwiftUI
import GardenCore

struct ScrapbookGardenView: View {
    let bundle: ArchiveBundle

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green.opacity(0.6))
            Text("Your Frozen Garden")
                .font(.title3.bold())
            Text("The garden is preserved as it was when your story was archived.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Label("Garden is frozen", systemImage: "snowflake")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
