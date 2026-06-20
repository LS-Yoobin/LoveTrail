import Foundation

struct LegalDocumentSection: Identifiable {
    let id = UUID()
    let heading: String
    let body: String
}

enum LegalDocumentType: String, Identifiable {
    case privacyPolicy
    case termsOfService

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacyPolicy:
            return "Privacy Policy"
        case .termsOfService:
            return "Terms of Service"
        }
    }

    var effectiveDateText: String {
        "Effective Date: June 2, 2026"
    }

    var sections: [LegalDocumentSection] {
        switch self {
        case .privacyPolicy:
            return [
                LegalDocumentSection(
                    heading: "Overview",
                    body: "Covela helps couples privately capture and revisit shared memories. This Privacy Policy explains what information we collect, how we use it, and the choices you have when using the app."
                ),
                LegalDocumentSection(
                    heading: "Information We Collect",
                    body: "We may collect information you provide directly, including your nickname, photos you select in the app, captions, and other memory content. We may also process optional metadata tied to selected photos, such as date and location, to organize your timeline and map features."
                ),
                LegalDocumentSection(
                    heading: "How We Use Information",
                    body: "We use your information to provide and improve core app features such as memory organization, timeline display, map experiences, reminders, and app personalization. We also use information to provide customer support, maintain app security, and comply with legal obligations."
                ),
                LegalDocumentSection(
                    heading: "Notifications & Permissions",
                    body: "Covela requests permissions like photo library access and notifications only to power specific features. You can manage or revoke permissions anytime in your device settings."
                ),
                LegalDocumentSection(
                    heading: "Subscriptions & Purchases",
                    body: "Subscription purchases are processed by Apple through your App Store account. We do not receive your full payment card details. Subscription management, renewals, and cancellations are handled in your Apple account settings."
                ),
                LegalDocumentSection(
                    heading: "Data Sharing",
                    body: "We do not sell your personal information. We may share limited data with service providers that help operate the app (for example, infrastructure or analytics support), and only as needed to provide the service securely."
                ),
                LegalDocumentSection(
                    heading: "Data Retention",
                    body: "We keep information for as long as needed to provide Covela and meet legal obligations. If you reset the app or request deletion where available, related app data may be removed from our systems and/or your device storage, subject to technical and legal limits."
                ),
                LegalDocumentSection(
                    heading: "Children's Privacy",
                    body: "Covela is not directed to children under 13, and we do not knowingly collect personal information from children under 13."
                ),
                LegalDocumentSection(
                    heading: "Your Rights",
                    body: "Depending on your location, you may have rights to access, correct, delete, or limit use of your personal information. To request help with privacy rights, contact us using the support details listed in the app listing."
                ),
                LegalDocumentSection(
                    heading: "Policy Updates",
                    body: "We may update this Privacy Policy from time to time. Material changes will be reflected by updating the effective date and, when required, providing additional notice."
                )
            ]
        case .termsOfService:
            return [
                LegalDocumentSection(
                    heading: "Acceptance of Terms",
                    body: "By downloading, accessing, or using Covela, you agree to these Terms of Service. If you do not agree, please do not use the app."
                ),
                LegalDocumentSection(
                    heading: "License to Use",
                    body: "We grant you a limited, non-exclusive, non-transferable, revocable license to use Covela for your personal, non-commercial use, subject to these Terms and Apple's applicable platform rules."
                ),
                LegalDocumentSection(
                    heading: "User Content",
                    body: "You are responsible for content you add to Covela, including photos, text, and other media. You represent that you have the rights needed to upload or use this content."
                ),
                LegalDocumentSection(
                    heading: "Acceptable Use",
                    body: "You agree not to misuse Covela, interfere with app operation, attempt unauthorized access, violate applicable laws, or infringe the rights of others."
                ),
                LegalDocumentSection(
                    heading: "Subscriptions",
                    body: "Certain features may require a paid subscription. Billing, renewal, and cancellation are managed by Apple through your App Store account in accordance with Apple subscription terms."
                ),
                LegalDocumentSection(
                    heading: "Termination",
                    body: "We may suspend or terminate access to Covela if these Terms are violated, if required by law, or for security and operational reasons."
                ),
                LegalDocumentSection(
                    heading: "Disclaimers",
                    body: "Covela is provided on an 'as is' and 'as available' basis to the extent permitted by law. We do not guarantee uninterrupted availability or that all features will always be error-free."
                ),
                LegalDocumentSection(
                    heading: "Limitation of Liability",
                    body: "To the maximum extent permitted by law, Covela and its operators are not liable for indirect, incidental, special, consequential, or punitive damages arising from your use of the app."
                ),
                LegalDocumentSection(
                    heading: "Changes to Terms",
                    body: "We may update these Terms from time to time. Continued use of Covela after updates means you accept the revised Terms."
                ),
                LegalDocumentSection(
                    heading: "Contact",
                    body: "If you have questions about these Terms, contact us using the support information listed in the App Store listing for Covela."
                )
            ]
        }
    }
}
