import Combine
import StoreKit

/// The paid "Invite Partner to Town" plans.
enum PartnerPlan: String, CaseIterable {
    case yearly = "LS.BabyTown.partner.yearly"
    case monthly = "LS.BabyTown.partner.monthly"
    case lifetime = "LS.BabyTown.partner.lifetime"

    /// Sort/display order: yearly, monthly, lifetime.
    var order: Int {
        switch self {
        case .yearly: return 0
        case .monthly: return 1
        case .lifetime: return 2
        }
    }

    var displayName: String {
        switch self {
        case .yearly: return "Yearly"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        }
    }

    /// Fallback price text used before StoreKit products load.
    var fallbackPrice: String {
        switch self {
        case .yearly: return "$29.99"
        case .monthly: return "$5.99"
        case .lifetime: return "$79"
        }
    }

    var isSubscription: Bool { self != .lifetime }
}

/// Owns all StoreKit 2 interaction for the partner tier: loading products,
/// purchasing, restoring, and tracking the unlock entitlement.
///
/// Entitlement truth comes from StoreKit (`Transaction.currentEntitlements`).
/// The persisted `DataPersistenceManager` flag is only a fast/offline mirror so
/// the Home banner renders correctly before StoreKit responds.
@MainActor
final class StoreManager: ObservableObject {

    static let shared = StoreManager()

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPartnerUnlocked: Bool
    @Published private(set) var activePlan: PartnerPlan?
    @Published var isPurchasing = false
    @Published var purchaseError: String?

    private var updatesTask: Task<Void, Never>?

    private enum StoreError: Error { case failedVerification }

    private init() {
        // Seed from the cached flag so the UI is correct before StoreKit answers.
        self.isPartnerUnlocked = DataPersistenceManager.shared.isPartnerUnlocked()
    }

    /// Call once at app launch.
    func start() {
        if updatesTask == nil {
            updatesTask = listenForTransactions()
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - Products

    func product(for plan: PartnerPlan) -> Product? {
        products.first { $0.id == plan.rawValue }
    }

    /// Localized price for a plan, falling back to hardcoded text if products
    /// haven't loaded yet.
    func displayPrice(for plan: PartnerPlan) -> String {
        product(for: plan)?.displayPrice ?? plan.fallbackPrice
    }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: PartnerPlan.allCases.map(\.rawValue))
            self.products = loaded.sorted { lhs, rhs in
                (PartnerPlan(rawValue: lhs.id)?.order ?? 99) < (PartnerPlan(rawValue: rhs.id)?.order ?? 99)
            }
        } catch {
            self.purchaseError = "Couldn't load plans. Please check your connection and try again."
        }
    }

    // MARK: - Purchase / Restore

    /// Returns true if the purchase completed and the partner tier is unlocked.
    @discardableResult
    func purchase(_ plan: PartnerPlan) async -> Bool {
        guard let product = product(for: plan) else {
            purchaseError = "That plan isn't available right now."
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return isPartnerUnlocked
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = "Purchase failed. Please try again."
            return false
        }
    }

    func restore() async {
        // Surfaces nothing on cancel; AppStore.sync prompts for auth.
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var unlocked = false
        var plan: PartnerPlan?

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard let matched = PartnerPlan(rawValue: transaction.productID) else { continue }
            unlocked = true
            // Lifetime takes precedence as the "best" active plan.
            if matched == .lifetime || plan == nil {
                plan = matched
            }
        }

        self.isPartnerUnlocked = unlocked
        self.activePlan = plan
        DataPersistenceManager.shared.setPartnerUnlocked(unlocked)
    }

    /// Clears the local unlock state so the banner/paywall return after Reset App
    /// for continued testing. Does not affect real StoreKit transactions — clear
    /// those in Xcode's Debug ▸ StoreKit ▸ Manage Transactions if needed.
    func resetForTesting() {
        isPartnerUnlocked = false
        activePlan = nil
        DataPersistenceManager.shared.setPartnerUnlocked(false)
    }

    // MARK: - Helpers

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                guard let transaction = try? self.checkVerified(result) else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
