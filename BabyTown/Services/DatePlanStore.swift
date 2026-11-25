import Foundation

final class DatePlanStore {
    static let shared = DatePlanStore()

    private static let fileName = "date_plans.json"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default
    private let lastSelectedKey = "plannerLastSelectedPlanID"

    /// `Documents/CovelaUserData/<scopeId>/date_plans.json`.
    ///
    /// Before storage became per account, every account on the device shared
    /// `Documents/date_plans.json`. That legacy file is left exactly as it is and is not
    /// read: nothing trustworthy says which account wrote each plan (`createdByUserID` is
    /// copied from an email the user can edit), so moving it to any account could show
    /// or upload another account's plans. This is also why the path is not
    /// `CovelaUserScope.scopedItem(named:)`, which would move the legacy file into
    /// whichever account opened it first.
    private var fileURL: URL {
        CovelaUserScope.documentsDirectory.appendingPathComponent(Self.fileName)
    }

    private init() {}

    // MARK: - Last Selected

    var lastSelectedPlanID: UUID? {
        guard let str = UserDefaults.standard.string(forKey: lastSelectedKey) else { return nil }
        return UUID(uuidString: str)
    }

    func setLastSelectedPlanID(_ id: UUID?) {
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: lastSelectedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastSelectedKey)
        }
    }

    // MARK: - CRUD

    func allPlans() -> [DatePlan] {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let plans = try? decoder.decode([DatePlan].self, from: data) else {
            return []
        }
        return plans
    }

    func upcomingPlans() -> [DatePlan] {
        allPlans()
            .filter { !$0.isPast }
            .sorted { $0.date < $1.date }
    }

    func createPlan(_ plan: DatePlan) {
        var plans = allPlans()
        plans.append(plan)
        persist(plans)
        notifySyncEngine()
    }

    func updatePlan(_ updated: DatePlan) {
        var plans = allPlans()
        guard let idx = plans.firstIndex(where: { $0.id == updated.id }) else { return }
        plans[idx] = updated
        persist(plans)
        notifySyncEngine()
    }

    func deletePlan(id: UUID) {
        var plans = allPlans()
        plans.removeAll { $0.id == id }
        persist(plans)
        if lastSelectedPlanID == id {
            setLastSelectedPlanID(nil)
        }
        notifySyncEngine()
    }

    /// Saves plans written by `DatePlansSyncResource` from pulled server changes.
    /// Does not notify the sync engine: these are not local edits.
    func replacePlansFromSync(_ plans: [DatePlan]) {
        persist(plans)
    }

    // MARK: - Persistence

    private func persist(_ plans: [DatePlan]) {
        guard let data = try? encoder.encode(plans) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Sync

    private func notifySyncEngine() {
        guard DatePlansSyncResource.isNetworkSyncEnabled else { return }
        CoupleSyncEngine.shared.localDidChange()
    }
}
