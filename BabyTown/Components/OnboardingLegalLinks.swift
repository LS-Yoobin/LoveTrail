import SwiftUI

struct OnboardingLegalLinks: View {
    @State private var activeDocument: LegalDocumentType?

    var body: some View {
        HStack(spacing: 16) {
            legalLinkButton(label: "Privacy Policy", document: .privacyPolicy)
            legalLinkButton(label: "Terms of Service", document: .termsOfService)
        }
        .frame(maxWidth: .infinity)
        .fullScreenCover(item: $activeDocument) { document in
            NavigationStack {
                LegalDocumentView(document: document)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                activeDocument = nil
                            }
                            .fontWeight(.semibold)
                        }
                    }
            }
        }
    }

    private func legalLinkButton(label: String, document: LegalDocumentType) -> some View {
        Button {
            activeDocument = document
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .underline()
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingLegalLinks()
}
