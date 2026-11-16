import Foundation

/// Shared couple coins through the server ledger (BAB-69, server BAB-141).
///
/// Decisions (2026-11-15): one shared balance; on pairing both partners' balances are
/// added together; earning works offline (queued with an idempotency key); spending
/// needs a connection and the server refuses a spend larger than the balance.
///
/// `PetState.coins` stays the number the UI shows. While paired it is a cache of
/// `server balance + not-yet-sent transactions`. Every earn and spend in
/// `PetViewModel` is recorded here; each sync run sends the queue, then takes the
/// server balance. Outside the Together phase coins stay purely local, as before.
@MainActor
final class CoinLedgerSync: CoupleSyncTask {
    static let shared = CoinLedgerSync()

    let key = "coins"

    enum Reason: String {
        case activity
        case checkIn = "check_in"
        case streak
        case bonus
        case shopPurchase = "shop_purchase"
        case rename
    }

    private struct PendingTransaction: Codable, Equatable {
        let idempotencyKey: String
        let type: String
        let amount: Int
        let reason: String

        var signedAmount: Int { type == "spend" ? -amount : amount }
    }

    private let dpm: DataPersistenceManager
    private let api: CovelaAPIClient
    private let pendingKey = "coinLedgerPending"
    private let depositDoneKey = "coinLedgerDepositDone"

    init(dpm: DataPersistenceManager = .shared, api: CovelaAPIClient = .shared) {
        self.dpm = dpm
        self.api = api
    }

    private var isActive: Bool {
        AuthService.shared.isSignedIn && dpm.loadCoupleProfile().relationshipStage == .officialCouple
    }

    /// Whether a spend may happen right now. Spending needs the server (so two phones
    /// can't spend the same coins); earning never does.
    var canSpendNow: Bool {
        !isActive || !CoupleSyncEngine.shared.isOffline
    }

    // MARK: Recording

    /// Call right after `PetViewModel` adds coins locally.
    func recordEarn(_ amount: Int, reason: Reason) {
        record(type: "earn", amount: amount, reason: reason)
    }

    /// Call right after `PetViewModel` removes coins locally.
    func recordSpend(_ amount: Int, reason: Reason) {
        record(type: "spend", amount: amount, reason: reason)
    }

    private func record(type: String, amount: Int, reason: Reason) {
        guard isActive, amount > 0 else { return }
        var pending = loadPending()
        pending.append(PendingTransaction(
            idempotencyKey: UUID().uuidString,
            type: type,
            amount: amount,
            reason: reason.rawValue
        ))
        savePending(pending)
        CoupleSyncEngine.shared.localDidChange()
    }

    /// Forgets the queue and the deposit flag (end of a relationship).
    func reset() {
        dpm.currentScopeDefaults.removeObject(forKey: pendingKey)
        dpm.currentScopeDefaults.removeObject(forKey: depositDoneKey)
    }

    // MARK: Sync

    func perform(token: String) async -> CoupleSyncTaskOutcome {
        // 1. One-time pairing deposit: this phone's balance from before pairing.
        if !dpm.currentScopeDefaults.bool(forKey: depositDoneKey) {
            let pendingNet = loadPending().reduce(0) { $0 + $1.signedAmount }
            let amount = min(max(dpm.loadPetState().coins - pendingNet, 0), 100_000)
            switch await post("couple/coins/migrate", body: ["amount": amount], token: token) {
            case .success:
                dpm.currentScopeDefaults.set(true, forKey: depositDoneKey)
            case .offline: return .offline
            case .notPaired: return .notPaired
            case .refused:
                // Can't be fixed by retrying; don't block the rest of coin sync.
                dpm.currentScopeDefaults.set(true, forKey: depositDoneKey)
            }
        }

        // 2. Send queued earns and spends, oldest first.
        for transaction in loadPending() {
            let path = transaction.type == "spend" ? "couple/coins/spend" : "couple/coins/earn"
            let result = await post(path, body: [
                "amount": transaction.amount,
                "reason": transaction.reason,
                "idempotency_key": transaction.idempotencyKey,
            ], token: token)
            switch result {
            case .success, .refused:
                // Refused (e.g. insufficient_balance): the server balance wins below.
                savePending(loadPending().filter { $0 != transaction })
            case .offline: return .offline
            case .notPaired: return .notPaired
            }
        }

        // 3. Take the server balance.
        let response: CovelaAPIClient.RawResponse
        do {
            response = try await api.send(method: "GET", path: "couple/coins", query: [URLQueryItem(name: "limit", value: "1")], token: token)
        } catch {
            return .offline
        }
        guard response.isSuccess, let balance = SyncJSON.int(response.jsonObject()?["balance"]) else {
            return response.status == 403 ? .notPaired : .ok
        }
        let pendingNet = loadPending().reduce(0) { $0 + $1.signedAmount }
        var state = dpm.loadPetState()
        let shown = max(balance + pendingNet, 0)
        guard state.coins != shown else { return .ok }
        state.coins = shown
        dpm.savePetState(state)
        return .changed
    }

    private enum PostResult { case success, refused, offline, notPaired }

    private func post(_ path: String, body: [String: Any], token: String) async -> PostResult {
        do {
            let response = try await api.send(method: "POST", path: path, body: body, token: token)
            switch response.status {
            case 200..<300: return .success
            case 401, 403: return .notPaired
            case 400..<500: return .refused
            default: return .offline
            }
        } catch {
            return .offline
        }
    }

    // MARK: Storage

    private func loadPending() -> [PendingTransaction] {
        guard let data = dpm.currentScopeDefaults.data(forKey: pendingKey),
              let pending = try? JSONDecoder().decode([PendingTransaction].self, from: data) else { return [] }
        return pending
    }

    private func savePending(_ pending: [PendingTransaction]) {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        dpm.currentScopeDefaults.set(data, forKey: pendingKey)
    }
}
