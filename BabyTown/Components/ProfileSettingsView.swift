import SwiftUI

struct ProfileSettingsView: View {
    @State private var email = ""
    @State private var username = ""
    @State private var birthday = Date()
    @State private var didLoadInitialValues = false
    @FocusState private var focusedField: ProfileField?

    private let dpm = DataPersistenceManager.shared
    private static let maxUsernameLength = 24

    private enum ProfileField: Hashable {
        case email, username
    }

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

    private var profileInitial: String {
        let source = trimmedUsername.isEmpty ? trimmedEmail : trimmedUsername
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [BabyTownTheme.cardTintLight, BabyTownTheme.cardTintDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                profileHeader
                accountCard
                infoFooter
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(BabyTownTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("Profile Settings")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(BabyTownTheme.accentIconBackdropGradient)
                    .frame(width: 88, height: 88)

                Text(profileInitial)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(BabyTownTheme.accentDeep)
            }
            .overlay(
                Circle()
                    .strokeBorder(BabyTownTheme.accentGradient, lineWidth: 2.5)
                    .frame(width: 88, height: 88)
            )
            .shadow(color: BabyTownTheme.cardShadow, radius: 10, y: 4)

            VStack(spacing: 6) {
                Text(trimmedUsername.isEmpty ? "Your Profile" : trimmedUsername)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(BabyTownTheme.textPrimary)

                Text("Changes save automatically when you leave this page.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Account Card

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            profileField(
                icon: "envelope.fill",
                title: "Email"
            ) {
                TextField("you@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .email)
            }

            fieldDivider

            profileField(
                icon: "person.fill",
                title: "Username"
            ) {
                TextField("Your username", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .username)
            }

            fieldDivider

            profileField(
                icon: "gift.fill",
                title: "Birthday"
            ) {
                DatePicker(
                    "",
                    selection: $birthday,
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(BabyTownTheme.accent)
            }

            if !trimmedUsername.isEmpty {
                Text("\(username.count)/\(Self.maxUsernameLength)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }

            if !trimmedEmail.isEmpty && !isEmailValid {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Enter a valid email address.")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(BabyTownTheme.accentDeep)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius, style: .continuous)
                .fill(cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BabyTownTheme.cardRadius, style: .continuous)
                .strokeBorder(BabyTownTheme.accent.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: BabyTownTheme.cardShadow, radius: 12, y: 4)
    }

    private var fieldDivider: some View {
        Rectangle()
            .fill(BabyTownTheme.accent.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private var infoFooter: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BabyTownTheme.accent)
                .padding(.top, 1)

            Text("Your profile details stay on this device and help personalize your Covela experience.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BabyTownTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func profileField<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(BabyTownTheme.accentSoft)
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.accentDeep)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BabyTownTheme.textSecondary)

                content()
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(BabyTownTheme.textPrimary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Data

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
        ProfileSettingsView()
    }
}
