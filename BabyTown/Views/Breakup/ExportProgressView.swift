import SwiftUI

struct ExportProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var progress: Double = 0
    @State private var exportText: String = ""
    @State private var done = false
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "doc.zipper")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            VStack(spacing: 10) {
                Text(done ? "Export ready" : "Preparing export…")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                Text(done
                     ? "All memories, dates, and captures included."
                     : "Gathering your memories and captures")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            if !done {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 48)
            } else {
                VStack(spacing: 14) {
                    Button {
                        showShareSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color.accentColor))
                    }
                    .buttonStyle(.plain)
                    Button("Done") { dismiss() }
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .task { await generateExport() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(text: exportText)
        }
    }

    private func generateExport() async {
        for step in 1...8 {
            try? await Task.sleep(nanoseconds: 150_000_000)
            progress = Double(step) / 8.0
        }
        exportText = ArchiveService.shared.generateExportText()
        done = true
    }
}

private struct ShareSheetView: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
