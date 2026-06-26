import SwiftUI

struct ProfileSettingsView: View {
    var onLogOut: () -> Void = {}

    @State private var email = ""
    @State private var username = ""
    @State private var birthday = Date()
    @State private var showLogOutConfirmation = false
    @State private var didLoadInitialValues = false

    private let dpm = DataPersistenceManager.shared
    private static let maxUsernameLength = 24

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEmailValid: Bool {
        let parts = trimmedEmail.split(separator: "@")
        return parts.count == 2 && (parts.last?.contains(".") == true)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileField(title: "Email") {
                    TextField("you@example.com", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                profileField(title: "Username") {
                    TextField("Your username", text: $username)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                }

                profileField(title: "Birthday") {
                    DatePicker(
                        "",
                        selection: $birthday,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }

                if !trimmedEmail.isEmpty && !isEmailValid {
                    Text("Enter a valid email address.")
                        .font(.system(size: 12))
                        .foregroundStyle(BabyTownTheme.textSecondary)
                }

                Divider()
                    .padding(.vertical, 4)

                Button(role: .destructive) {
                    showLogOutConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16))
                        Text("Log Out")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle("Profile Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Log out of Covela?",
            isPresented: $showLogOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive) {
                persistChanges()
                onLogOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data stays on this device.")
        }
        .onAppear {
            loadInitialValues()
        }
        .onDisappear {
            guard didLoadInitialValues else { return }
            persistChanges()
        }
        .onChange(of: username) { _, newValue in
            if newValue.count > Self.maxUsernameLength {
                username = String(newValue.prefix(Self.maxUsernameLength))
            }
        }
    }

    @ViewBuilder
    private func profileField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.textSecondary)

            content()
                .font(.system(size: 16))
                .foregroundStyle(BabyTownTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(BabyTownTheme.blushSoft)
                )
        }
    }

    private func loadInitialValues() {
        email = dpm.loadUserEmail()
            ?? AuthService.shared.currentUser?.email
            ?? ""
        username = dpm.loadUserNickname() ?? ""

        let profile = dpm.loadCoupleProfile()
        if let entry = profile.specialDates.first(where: { $0.id == SpecialDate.localUserBirthdayID }) {
            birthday = entry.date
        }

        didLoadInitialValues = true
    }

    private func persistChanges() {
        guard didLoadInitialValues else { return }

        if !trimmedEmail.isEmpty, isEmailValid {
            dpm.saveUserEmail(trimmedEmail)
        }

        let nicknameForBirthday = trimmedUsername.isEmpty
            ? (dpm.loadUserNickname() ?? "You")
            : trimmedUsername

        if !trimmedUsername.isEmpty {
            dpm.saveUserNickname(trimmedUsername)
            if !dpm.isPartnerAccount() {
                var profile = dpm.loadCoupleProfile()
                profile.displayName = trimmedUsername
                dpm.saveCoupleProfile(profile)
            }
        }

        dpm.saveOnboardingUserBirthday(birthday, nickname: nicknameForBirthday)
    }
}

#Preview {
    NavigationStack {
        ProfileSettingsView(onLogOut: {})
    }
}
