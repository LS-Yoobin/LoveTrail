import SwiftUI

struct OnboardingBackButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("<")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.black)
                .frame(width: 44, height: 44, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

extension View {
    func onboardingBackButton(action: @escaping () -> Void) -> some View {
        overlay(alignment: .topLeading) {
            OnboardingBackButton(action: action)
                .padding(.leading, 12)
                .padding(.top, 4)
        }
    }
}
