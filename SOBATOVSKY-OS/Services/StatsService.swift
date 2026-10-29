import Foundation

struct StatsSnapshot {
    var tasksDone = 0
    var focusMinutes = 0
    var completedSessions = 0
    var reviewsTotal = 0
    var cardsStudied = 0
    var notes = 0
    var currentStreak = 0
    var maxStreak = 0
    var activeDays = 0
    var totalXP = 0
    var level = 1
}

struct DayStats {
    var tasksDone: Int
    var focusMinutes: Int
    var xp: Int
    var taskGoal: Int
    var focusGoal: Int
    var progress: Double {
        let t = taskGoal > 0 ? min(1, Double(tasksDone) / Double(taskGoal)) : 1
        let f = focusGoal > 0 ? min(1, Double(focusMinutes) / Double(focusGoal)) : 1
        return (t + f) / 2
    }
}

enum StatsService {
    /// День считается активным, если завершена задача или сессия фокуса либо повторена карточка.
    static func activeDays(_ d: AppData) -> Set<Date> {
        var s = Set<Date>()
        for e in d.events where e.kind == .task || e.kind == .focus { s.insert(e.date.startOfDay) }
        for r in d.reviews where r.rating != .again { s.insert(r.date.startOfDay) }
        return s
    }

    static func streaks(days: Set<Date>, today: Date = Date()) -> (current: Int, max: Int) {
        var cur = 0
        var cursor = today.startOfDay
        if !days.contains(cursor) { cursor = cursor.addingDays(-1) }
        while days.contains(cursor) { cur += 1; cursor = cursor.addingDays(-1) }

        var best = 0, run = 0
        var prev: Date?
        for day in days.sorted() {
            if let p = prev, p.addingDays(1) == day { run += 1 } else { run = 1 }
            best = Swift.max(best, run)
            prev = day
        }
        return (cur, best)
    }

    static func snapshot(_ d: AppData, today: Date = Date()) -> StatsSnapshot {
        var s = StatsSnapshot()
        s.tasksDone = d.tasks.filter { $0.isDone }.count
        s.focusMinutes = Int(d.sessions.reduce(0) { $0 + $1.countedMinutes })
        s.completedSessions = d.sessions.filter { $0.completed }.count
        s.reviewsTotal = d.reviews.count
        s.cardsStudied = d.cards.filter { $0.correctCount > 0 }.count
        s.notes = d.notes.count
        let days = activeDays(d)
        let st = streaks(days: days, today: today)
        s.currentStreak = st.current
        s.maxStreak = st.max
        s.activeDays = days.count
        s.totalXP = d.events.reduce(0) { $0 + $1.amount }
        s.level = LevelCurve.level(for: s.totalXP)
        return s
    }

    static func focusMinutes(_ d: AppData, from: Date, to: Date) -> Double {
        d.sessions.filter { $0.endedAt >= from && $0.endedAt < to }.reduce(0) { $0 + $1.countedMinutes }
    }
    static func tasksDone(_ d: AppData, from: Date, to: Date) -> Int {
        d.tasks.filter { t in
            guard t.isDone, let c = t.completedAt else { return false }
            return c >= from && c < to
        }.count
    }
    static func reviewCount(_ d: AppData, from: Date, to: Date) -> Int {
        d.reviews.filter { $0.date >= from && $0.date < to }.count
    }
    static func xp(_ d: AppData, from: Date, to: Date) -> Int {
        d.events.filter { $0.date >= from && $0.date < to }.reduce(0) { $0 + $1.amount }
    }
    static func completedSessions(_ d: AppData, from: Date, to: Date) -> Int {
        d.sessions.filter { $0.completed && $0.endedAt >= from && $0.endedAt < to }.count
    }
    static func activityCount(_ d: AppData, from: Date, to: Date) -> Int {
        tasksDone(d, from: from, to: to) + completedSessions(d, from: from, to: to) + reviewCount(d, from: from, to: to)
    }

    static func goalValue(_ g: Goal, in d: AppData, now: Date = Date()) -> Double {
        let from = g.startDate
        let to = Date.distantFuture
        switch g.kind {
        case .manual:
            return g.manualValue
        case .focusMinutes:
            return d.sessions.filter { s in
                s.endedAt >= from && s.endedAt < to && (g.subjectID == nil || s.subjectID == g.subjectID)
            }.reduce(0) { $0 + $1.countedMinutes }
        case .tasksDone:
            return Double(tasksDone(d, from: from, to: to))
        case .sessions:
            return Double(d.sessions.filter { $0.completed && $0.endedAt >= from && (g.subjectID == nil || $0.subjectID == g.subjectID) }.count)
        case .cardsReviewed:
            return Double(reviewCount(d, from: from, to: to))
        }
    }
}
