import SwiftUI

struct UserBirthdayView: View {

    var onBack: () -> Void
    var onContinue: (Date) -> Void

    @State private var birthday: Date
    @State private var contentOpacity: Double = 0

    private var dateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .year, value: -120, to: end) ?? end
        return start...end
    }

    init(onBack: @escaping () -> Void, onContinue: @escaping (Date) -> Void) {
        self.onBack = onBack
        self.onContinue = onContinue
        let defaultDate = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
        _birthday = State(initialValue: defaultDate)
    }

    var body: some View {
        ZStack {
            background

            FloatingHeartsView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    Text("When's your birthday?")
                        .font(.system(size: 31, weight: .semibold, design: .rounded))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("We'll save it in your Important Dates")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.66))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

                DatePicker(
                    "Birthday",
                    selection: $birthday,
                    in: dateRange,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .foregroundStyle(Color.black)
                .colorScheme(.light)
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 14) {
                    continueButton
                    OnboardingLegalLinks()
                }
            }
            .opacity(contentOpacity)
        }
        .onboardingBackButton(action: onBack)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                contentOpacity = 1.0
            }
        }
    }

    private var background: some View {
        ZStack {
            BabyTownTheme.backgroundCream

            VStack(spacing: 0) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.76, blue: 0.68).opacity(0.36),
                                Color(red: 0.72, green: 0.82, blue: 1.0).opacity(0.2)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 360, height: 120)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -70, y: 58)

                Spacer()

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.86, blue: 0.46).opacity(0.22),
                                BabyTownTheme.accent.opacity(0.16)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 420, height: 150)
                    .rotationEffect(.degrees(14))
                    .offset(x: 95, y: -44)
            }

            VStack {
                HStack {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(BabyTownTheme.accentDeep.opacity(0.14))
                        .offset(x: 34, y: 86)
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color(red: 0.94, green: 0.57, blue: 0.16).opacity(0.16))
                        .offset(x: -36, y: 132)
                }
                Spacer()
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private var continueButton: some View {
        Button {
            onContinue(SpecialDate.normalizedTimelineDay(birthday))
        } label: {
            Text("Continue")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(BabyTownTheme.buttonGradient)
                        .shadow(color: BabyTownTheme.accent.opacity(0.3), radius: 12, y: 6)
                )
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 8)
    }
}

#Preview {
    UserBirthdayView(onBack: {}, onContinue: { date in
        print("birthday: \(date)")
    })
}
