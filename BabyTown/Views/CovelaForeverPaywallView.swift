import SwiftUI

struct CovelaForeverPaywallView: View {

    @ObservedObject var store: StoreManager
    var onUnlock: () -> Void
    var onDismiss: () -> Void

    @State private var showAllPlans = false
    @State private var appear = false
    @State private var showError = false

    private var accent: Color { BabyTownTheme.accentDeep }
    private var heroGradient: [Color] { [BabyTownTheme.accent, BabyTownTheme.accentDeep] }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, accent.opacity(0.10)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            LoopingVideoPlayer(videoName: "transparent_flowers")
                .frame(height: 300)
                .mask(
                    LinearGradient(
                        colors: [.clear, .black, .black],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .blendMode(.screen)
                .allowsHitTesting(false)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                closeRow
                hero
                benefitsList
                    .padding(.top, 18)
                bothBanner
                    .padding(.top, 18)
                yearlyHeroCard
                    .padding(.top, 18)
                cta
                    .padding(.top, 16)
                seeAllPlansButton
                    .padding(.top, 12)
                finePrint
                    .padding(.top, 12)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 12)

            if store.isPurchasing {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView()
                    .controlSize(.large)
                    .tint(accent)
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { appear = true }
        }
        .sheet(isPresented: $showAllPlans) {
            ForeverAllPlansSheet(
                accent: accent,
                store: store,
                onPurchase: { plan in buy(plan) }
            )
            .presentationDetents([.height(500)])
            .presentationDragIndicator(.visible)
            .presentationBackground(BabyTownTheme.cardBackground)
        }
        .alert("Purchase Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { store.purchaseError = nil }
        } message: {
            Text(store.purchaseError ?? "Something went wrong. Please try again.")
        }
    }

    // MARK: - Purchase

    private func buy(_ plan: ForeverPlan) {
        Task {
            let unlocked = await store.purchase(plan)
            if unlocked {
                onUnlock()
            } else if store.purchaseError != nil {
                showError = true
            }
        }
    }

    private func restore() {
        Task {
            await store.restore()
            if store.isForeverUnlocked { onUnlock() }
        }
    }

    // MARK: - Sections

    private var closeRow: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.35))
                    .frame(width: 32, height: 32)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var hero: some View {
        VStack(spacing: 0) {
            Image("BabyTownFullIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 15.75, style: .continuous))
                .shadow(color: accent.opacity(0.38), radius: 12, y: 6)
                .padding(.bottom, 16)

            Text("Keep every memory,\nforever")
                .font(.system(size: 25, weight: .heavy))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black.opacity(0.85))

            Text("Your full story, always within reach")
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 12)
                .padding(.top, 8)
        }
    }

    private var benefitsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow(icon: "photo.on.rectangle.angled", text: "Every moment, always — your full timeline with no limits")
            benefitRow(icon: "envelope.open.fill",       text: "Letters that last — read and write beyond 30 days")
            benefitRow(icon: "calendar.badge.plus",      text: "Unlimited important dates — every milestone, saved forever")
            benefitRow(icon: "pin.fill",                 text: "Unlimited pinned moments — keep what matters most")
            benefitRow(icon: "heart.fill",               text: "One purchase for both of you — covers you and your partner")
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(accent)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bothBanner: some View {
        (Text("One purchase unlocks Forever for ")
            + Text("both").fontWeight(.bold)
            + Text(" of you"))
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: heroGradient, startPoint: .leading, endPoint: .trailing))
            )
    }

    private var yearlyHeroCard: some View {
        Button { buy(.yearly) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Yearly")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.85))
                    Text("$2.50/mo · save ~58%")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.black.opacity(0.5))
                }
                Spacer()
                Text(store.displayPrice(for: .yearly))
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.black.opacity(0.85))
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [.white, accent.opacity(0.06)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(accent, lineWidth: 2)
            )
            .overlay(alignment: .topLeading) {
                Text("7-DAY FREE TRIAL")
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(accent))
                    .offset(x: 14, y: -10)
            }
        }
        .buttonStyle(.plain)
    }

    private var cta: some View {
        Button { buy(.yearly) } label: {
            Text("Start 7-day free trial")
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: heroGradient, startPoint: .leading, endPoint: .trailing))
                        .shadow(color: accent.opacity(0.34), radius: 14, y: 6)
                )
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
    }

    private var seeAllPlansButton: some View {
        Button { showAllPlans = true } label: {
            Text("See all Plans")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var finePrint: some View {
        VStack(spacing: 6) {
            Text("Then \(store.displayPrice(for: .yearly))/year · Cancel anytime")
            Button(action: restore) {
                Text("Restore purchase")
                    .underline()
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 10))
        .foregroundStyle(.black.opacity(0.35))
        .multilineTextAlignment(.center)
    }
}

// MARK: - All Plans sheet

private struct ForeverAllPlansSheet: View {

    let accent: Color
    @ObservedObject var store: StoreManager
    var onPurchase: (ForeverPlan) -> Void

    private let cardHeight: CGFloat = 96

    var body: some View {
        VStack(spacing: 0) {
            Text("CHOOSE A PLAN")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.black.opacity(0.45))
                .padding(.top, 20)
                .padding(.bottom, 16)

            planCard(.yearly,  title: "Yearly + 7-day free trial",
                     primary: "\(store.displayPrice(for: .yearly))/year for 2 users",
                     secondary: "$1.25 per user/month", badge: "BEST DEAL", highlighted: true)
                .padding(.bottom, 10)

            planCard(.monthly, title: "Monthly",
                     primary: "\(store.displayPrice(for: .monthly))/month for 2 users",
                     secondary: "$3.00 per user/month", badge: nil, highlighted: false)
                .padding(.bottom, 10)

            planCard(.lifetime, title: "Lifetime",
                     primary: "\(store.displayPrice(for: .lifetime)) once for 2 users",
                     secondary: "One payment, forever", badge: nil, highlighted: false)

            Text("Cancel anytime in the App Store")
                .font(.system(size: 11.5))
                .foregroundStyle(.black.opacity(0.42))
                .padding(.top, 14)
                .padding(.bottom, 20)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(BabyTownTheme.cardBackground)
    }

    private func planCard(
        _ plan: ForeverPlan,
        title: String,
        primary: String,
        secondary: String,
        badge: String?,
        highlighted: Bool
    ) -> some View {
        Button { onPurchase(plan) } label: {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.88))
                        .lineLimit(2).minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(primary)
                        .font(.system(size: 13))
                        .foregroundStyle(.black.opacity(0.55))
                    Text(secondary)
                        .font(.system(size: 12))
                        .foregroundStyle(.black.opacity(0.42))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, badge == nil ? 0 : 72)

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(accent))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(highlighted ? 1 : 0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(highlighted ? accent.opacity(0.85) : Color.black.opacity(0.12),
                            lineWidth: highlighted ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(store.isPurchasing)
    }
}

#Preview {
    CovelaForeverPaywallView(store: .shared, onUnlock: {}, onDismiss: {})
}
