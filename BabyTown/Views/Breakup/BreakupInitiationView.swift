import SwiftUI

struct BreakupInitiationView: View {
    var onComplete: () -> Void
    var onCancel: () -> Void

    @State private var stage: Stage = .confirmation
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?

    enum Stage { case confirmation, uploading, failed }

    var body: some View {
        switch stage {
        case .confirmation:
            confirmationView
        case .uploading:
            uploadingView
        case .failed:
            failedView
        }
    }

    private var confirmationView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Archive Your Story")
                .font(.title2.bold())
            Text("This will archive your story. You'll both have 30 days to export your memories or reconnect.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Spacer()
            Button(role: .destructive) {
                Task { await startBreakup() }
            } label: {
                Text("End Relationship")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .padding(.horizontal, 32)
            Button("Cancel", action: onCancel)
                .padding(.bottom, 32)
        }
    }

    private var uploadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView("Archiving your memories…", value: uploadProgress)
                .padding(.horizontal, 40)
            Text("This may take a moment for large photo libraries.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var failedView: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Something went wrong")
                .font(.title3.bold())
            Text(errorMessage ?? "Please check your connection and try again.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task { await startBreakup() }
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel", action: onCancel)
            Spacer()
        }
    }

    private func startBreakup() async {
        stage = .uploading
        uploadProgress = 0
        do {
            try await ArchiveService.shared.initiateBreakup { fraction in
                Task { @MainActor in uploadProgress = fraction }
            }
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
            stage = .failed
        }
    }
}
