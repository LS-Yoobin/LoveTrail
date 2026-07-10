import SwiftUI

struct OnboardingBackButton: View {

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.system(size: 22, weight: .bold))
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
