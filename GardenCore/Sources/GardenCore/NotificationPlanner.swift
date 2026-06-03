import Foundation

public struct PetNeedSnapshot: Equatable {
    public var level: Double          // current 0–100 at snapshot `now`
    public var decayPerHour: Double
    public var gate: Double           // "low" threshold (PetEconomy.feedThirstGate)
    public init(level: Double, decayPerHour: Double, gate: Double) {
        self.level = level; self.decayPerHour = decayPerHour; self.gate = gate
    }
}

public struct PlannerSpecialDate: Equatable {
    public var id: String
    public var title: String
    public var date: Date
    public init(id: String, title: String, date: Date) {
        self.id = id; self.title = title; self.date = date
    }
}

public struct NotificationSnapshot: Equatable {
    public var isPetAdopted: Bool
    public var petName: String?
    public var userNickname: String?
    public var lastPetInteractionAt: Date?
    public var litterIsDirty: Bool
    public var hunger: PetNeedSnapshot?
    public var thirst: PetNeedSnapshot?
    public var specialDates: [PlannerSpecialDate]
    public init(isPetAdopted: Bool, petName: String?, userNickname: String?,
                lastPetInteractionAt: Date?, litterIsDirty: Bool,
                hunger: PetNeedSnapshot?, thirst: PetNeedSnapshot?,
                specialDates: [PlannerSpecialDate]) {
        self.isPetAdopted = isPetAdopted; self.petName = petName
        self.userNickname = userNickname; self.lastPetInteractionAt = lastPetInteractionAt
        self.litterIsDirty = litterIsDirty; self.hunger = hunger; self.thirst = thirst
        self.specialDates = specialDates
    }
}

public enum PlannedTrigger: Equatable {
    case interval(TimeInterval)                                   // one-shot, seconds from now
    case calendarDaily(hour: Int, minute: Int)                   // repeats daily
    case calendarAnnual(month: Int, day: Int, hour: Int, minute: Int)  // repeats yearly
}

public struct PlannedNotification: Equatable {
    public var id: String
    public var title: String
    public var body: String
    public var trigger: PlannedTrigger
}

public struct NotificationPlanner {
    public init() {}

    public func plan(snapshot s: NotificationSnapshot, now: Date, calendar: Calendar) -> [PlannedNotification] {
        var out: [PlannedNotification] = []
        if s.isPetAdopted {
            out.append(petMissesYou(s, now: now, calendar: calendar))
            if s.litterIsDirty { out.append(litterNoon(s)) }
            if let needs = petNeeds(s, now: now, calendar: calendar) { out.append(needs) }
        }
        out.append(contentsOf: specialDates(s, calendar: calendar))
        return out
    }

    private func petMissesYou(_ s: NotificationSnapshot, now: Date, calendar: Calendar) -> PlannedNotification {
        let name = s.petName ?? "Someone"
        let candidate = (s.lastPetInteractionAt ?? now).addingTimeInterval(7 * 86_400)
        let target = max(candidate, now)
        let fire = NotificationQuietHours.clamp(target, calendar: calendar)
        let body: String
        if let nick = s.userNickname, !nick.isEmpty {
            body = "Hi \(nick), \(name) misses you 🐾"
        } else {
            body = "\(name) misses you 🐾"
        }
        return PlannedNotification(id: "pet_misses_you", title: "\(name) misses you",
                                   body: body, trigger: .interval(max(1, fire.timeIntervalSince(now))))
    }

    private func litterNoon(_ s: NotificationSnapshot) -> PlannedNotification {
        let name = s.petName ?? "Your pet"
        return PlannedNotification(id: "litter_box_noon", title: "Litter box needs you",
                                   body: "\(name)'s litter box could use a cleanup 🧹",
                                   trigger: .calendarDaily(hour: 12, minute: 0))
    }

    private func petNeeds(_ s: NotificationSnapshot, now: Date, calendar: Calendar) -> PlannedNotification? {
        func hoursToGate(_ need: PetNeedSnapshot?) -> Double? {
            guard let need, need.decayPerHour > 0 else { return nil }
            let remaining = need.level - need.gate
            return remaining <= 0 ? 0 : remaining / need.decayPerHour
        }
        let h = hoursToGate(s.hunger)
        let t = hoursToGate(s.thirst)
        guard let soonest = [h, t].compactMap({ $0 }).min() else { return nil }
        let fire = NotificationQuietHours.clamp(now.addingTimeInterval(soonest * 3600), calendar: calendar)
        let name = s.petName ?? "Your pet"
        let title: String
        let body: String
        if h == 0 && t == 0 {
            title = "\(name) needs you"; body = "\(name) is hungry and thirsty"
        } else if (h ?? .infinity) <= (t ?? .infinity) {
            title = "\(name) is getting hungry 🍽️"; body = "Time to refill the food bowl"
        } else {
            title = "\(name) is thirsty 💧"; body = "Time to refill the water bowl"
        }
        return PlannedNotification(id: "pet_needs", title: title, body: body,
                                   trigger: .interval(max(1, fire.timeIntervalSince(now))))
    }

    private func specialDates(_ s: NotificationSnapshot, calendar: Calendar) -> [PlannedNotification] {
        s.specialDates.map { sd in
            let comps = calendar.dateComponents([.month, .day], from: sd.date)
            return PlannedNotification(
                id: "special_date_\(sd.id)",
                title: "\(sd.title) 💞",
                body: "Today's the day — \(sd.title).",
                trigger: .calendarAnnual(month: comps.month ?? 1, day: comps.day ?? 1, hour: 9, minute: 0))
        }
    }

    public static let momentMilestones = [10, 50, 100, 250, 500, 1000]

    /// Milestones strictly above `oldCount`, at or below `newCount`, not yet
    /// celebrated. Caller fires the max (one banner per batch) and records all
    /// returned values as celebrated so the skipped lower ones never re-fire.
    public func crossedMilestones(oldCount: Int, newCount: Int, alreadyCelebrated: Set<Int>) -> [Int] {
        guard newCount > oldCount else { return [] }
        return Self.momentMilestones.filter { $0 > oldCount && $0 <= newCount && !alreadyCelebrated.contains($0) }
    }
}
