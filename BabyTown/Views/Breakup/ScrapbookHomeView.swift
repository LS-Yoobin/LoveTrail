import SwiftUI

struct ScrapbookHomeView: View {
    var bundle: ArchiveBundle
    var onStepOut: () -> Void
    var onReconnect: () -> Void

    @State private var showExport = false
    @State private var showStepOutConfirmation = false
    @State private var showReconnect = false
    @State private var selectedTab: Tab = .memories

    enum Tab { case memories, garden, pet }

    var body: some View {
        VStack(spacing: 0) {
            retentionBar
            reconnectBanner
            tabContent
            tabBar
        }
        .sheet(isPresented: $showExport) {
            ExportProgressView()
        }
        .sheet(isPresented: $showStepOutConfirmation) {
            StepOutConfirmationView(onConfirmed: onStepOut)
        }
        .sheet(isPresented: $showReconnect) {
            ReconnectInviteView(onReconnected: onReconnect)
        }
    }

    private var retentionBar: some View {
        HStack {
            Text(expiryLabel(bundle.expiryDate))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Export") { showExport = true }
                .font(.caption.bold())
            Button("Extend") {
                Task { try? await ArchiveService.shared.extendRetention() }
            }
            .font(.caption.bold())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var reconnectBanner: some View {
        Button {
            showReconnect = true
        } label: {
            HStack {
                Image(systemName: "heart")
                Text("Changed your mind? Invite \(bundle.coupleProfile.displayName ?? "them") back")
                    .font(.subheadline)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .memories:
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(bundle.moments.sorted { $0.dateTaken > $1.dateTaken }) { moment in
                        ScrapbookMomentRow(moment: moment)
                    }
                }
                .padding(16)
            }
        case .garden:
            ScrapbookGardenView(bundle: bundle)
        case .pet:
            ScrapbookPetView(bundle: bundle)
        }
    }

    private var tabBar: some View {
        HStack {
            tabButton("Memories", systemImage: "photo.stack", tab: .memories)
            tabButton("Garden", systemImage: "leaf", tab: .garden)
            tabButton("Pet", systemImage: "pawprint", tab: .pet)
            Spacer()
            Button {
                showStepOutConfirmation = true
            } label: {
                Text("Start Fresh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func tabButton(_ label: String, systemImage: String, tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(label).font(.caption2)
            }
            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func expiryLabel(_ expiry: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        return "Memories available for \(max(days, 0)) more day\(days == 1 ? "" : "s")"
    }
}

// MARK: - Moment Row (read-only)

private struct ScrapbookMomentRow: View {
    let moment: Moment
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(uiImage: moment.thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                if let caption = moment.caption {
                    Text(caption).font(.subheadline)
                }
                if let place = moment.placeName {
                    Text(place).font(.caption).foregroundStyle(.secondary)
                }
                Text(moment.dateTaken, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }
}
