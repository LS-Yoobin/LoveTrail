import Foundation

final class DatePlanStore {
    static let shared = DatePlanStore()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default
    private let lastSelectedKey = "plannerLastSelectedPlanID"

    private var fileURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("date_plans.json")
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
        Task { await syncToMongoDB(plan) }
    }

    func updatePlan(_ updated: DatePlan) {
        var plans = allPlans()
        guard let idx = plans.firstIndex(where: { $0.id == updated.id }) else { return }
        plans[idx] = updated
        persist(plans)
        Task { await syncToMongoDB(updated) }
    }

    func deletePlan(id: UUID) {
        var plans = allPlans()
        plans.removeAll { $0.id == id }
        persist(plans)
        if lastSelectedPlanID == id {
            setLastSelectedPlanID(nil)
        }
    }

    // MARK: - Persistence

    private func persist(_ plans: [DatePlan]) {
        guard let data = try? encoder.encode(plans) else { return }
        try? data.write(to: fileURL)
    }

    // MARK: - Sync stubs

    private func syncToMongoDB(_ plan: DatePlan) async {
        // TODO: POST /date_plans with { coupleID, plan } — last-write-wins on updatedAt
    }

    func fetchPartnerChanges() async {
        // TODO: GET /date_plans?coupleID=X — merge by updatedAt per plan id
    }
}
