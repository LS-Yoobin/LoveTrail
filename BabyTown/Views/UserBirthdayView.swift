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
            LinearGradient(
                colors: [.white, BabyTownTheme.accent.opacity(0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    Text("When's your birthday?")
                        .font(.system(size: 26, weight: .light, design: .serif))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("We'll save it in your Important Dates")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(.secondaryLabel))
                        .multilineTextAlignment(.center)
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

    private var continueButton: some View {
        Button {
            onContinue(SpecialDate.normalizedTimelineDay(birthday))
        } label: {
            Text("Continue")
                .font(.system(size: 17, weight: .medium))
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
