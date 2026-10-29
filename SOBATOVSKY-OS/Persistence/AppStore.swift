import SwiftUI
import Combine

enum AppTab: Int, CaseIterable, Identifiable {
    case overview, tasks, knowledge, focus, progress
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .overview: return "Обзор"
        case .tasks: return "Задачи"
        case .knowledge: return "Знания"
        case .focus: return "Фокус"
        case .progress: return "Прогресс"
        }
    }
    var icon: String {
        switch self {
        case .overview: return "square.grid.2x2.fill"
        case .tasks: return "checklist"
        case .knowledge: return "books.vertical.fill"
        case .focus: return "timer"
        case .progress: return "chart.bar.xaxis"
        }
    }
}

struct XPToast: Identifiable, Equatable {
    let id = UUID()
    let amount: Int
    let title: String
}

/// Единый источник истины приложения.
final class AppStore: ObservableObject {
    @Published var data: AppData {
        didSet {
            SBMotion.enabled = data.settings.animations
            Haptics.enabled = data.settings.haptics
            scheduleSave()
        }
    }
    @Published var selectedTab: AppTab = .overview
    @Published var dayTick = Date()
    @Published var startupMessage: String?
    @Published var toast: XPToast?

    private var saveItem: DispatchWorkItem?
    private var notifItem: DispatchWorkItem?
    private var bag = Set<AnyCancellable>()

    init() {
        let loaded = LocalStorage.load()
        data = loaded.data
        startupMessage = loaded.message
        SBMotion.enabled = loaded.data.settings.animations
        Haptics.enabled = loaded.data.settings.haptics
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.dayTick = Date() }
            .store(in: &bag)
    }

    // MARK: Сохранение

    private func scheduleSave() {
        saveItem?.cancel()
        let snapshot = data
        let item = DispatchWorkItem { LocalStorage.save(snapshot) }
        saveItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    func flush() {
        saveItem?.cancel()
        LocalStorage.save(data)
    }

    func scheduleNotificationSync() {
        notifItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.syncNotifications() }
        notifItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: item)
    }

    func syncNotifications() {
        NotificationService.syncTasks(data.tasks, enabled: data.settings.taskReminders)
        NotificationService.syncHabits(data.habits)
        NotificationService.syncCardReminder(enabled: data.settings.cardReminderEnabled, hour: data.settings.cardReminderHour)
    }

    // MARK: Награды

    @discardableResult
    func award(key: String, kind: EventKind, title: String, amount: Int, date: Date = Date(), showToast: Bool = true) -> Bool {
        guard !data.events.contains(where: { $0.key == key }) else { return false }
        data.events.append(XPEvent(key: key, kind: kind, title: title, amount: amount, date: date))
        if amount > 0 && showToast && data.settings.xpToast { presentToast(amount: amount, title: title) }
        return true
    }

    func removeEvent(key: String) {
        data.events.removeAll { $0.key == key }
    }

    private func presentToast(amount: Int, title: String) {
        let t = XPToast(amount: amount, title: title)
        withAnimation(SBMotion.anim) { toast = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self = self, self.toast?.id == t.id else { return }
            withAnimation(SBMotion.anim) { self.toast = nil }
        }
    }

    func afterMutation() {
        evaluateAchievements()
        scheduleNotificationSync()
    }

    func evaluateAchievements() {
        let s = StatsService.snapshot(data)
        for def in AchievementCatalog.all where !data.achievements.contains(where: { $0.id == def.id }) {
            if def.current(s) >= def.goal {
                data.achievements.append(AchievementRecord(id: def.id, unlockedAt: Date()))
                award(key: "ach:\(def.id)", kind: .achievement, title: "Достижение: \(def.title)",
                      amount: XPBalance.achievementBonus)
            }
        }
    }

    // MARK: Задачи

    func task(_ id: UUID) -> TaskItem? { data.tasks.first { $0.id == id } }

    func addTask(_ t: TaskItem) {
        data.tasks.append(t)
        afterMutation()
    }

    func updateTask(_ t: TaskItem) {
        guard let i = data.tasks.firstIndex(where: { $0.id == t.id }) else { return }
        data.tasks[i] = t
        afterMutation()
    }

    func deleteTask(_ id: UUID) {
        data.tasks.removeAll { $0.id == id }
        removeEvent(key: "task:\(id.uuidString)")
        afterMutation()
    }

    func toggleTask(_ id: UUID) {
        guard let i = data.tasks.firstIndex(where: { $0.id == id }) else { return }
        let t = data.tasks[i]
        if t.isDone {
            if let nid = t.spawnedNextID {
                data.tasks.removeAll { $0.id == nid && !$0.isDone }
            }
            guard let k = data.tasks.firstIndex(where: { $0.id == id }) else { return }
            data.tasks[k].isDone = false
            data.tasks[k].completedAt = nil
            data.tasks[k].spawnedNextID = nil
            removeEvent(key: "task:\(id.uuidString)")
        } else {
            data.tasks[i].isDone = true
            data.tasks[i].completedAt = Date()
            award(key: "task:\(id.uuidString)", kind: .task, title: t.title, amount: t.xp)
            if t.repeatRule != .none, let due = t.dueDate {
                var next = t
                next.id = UUID()
                next.dueDate = t.repeatRule.next(after: due)
                next.isDone = false
                next.completedAt = nil
                next.spawnedNextID = nil
                next.createdAt = Date()
                data.tasks[i].spawnedNextID = next.id
                data.tasks.append(next)
            }
            Haptics.success()
        }
        afterMutation()
    }

    // MARK: Предметы, темы

    func subject(_ id: UUID?) -> Subject? {
        guard let id = id else { return nil }
        return data.subjects.first { $0.id == id }
    }
    func subjectName(_ id: UUID?) -> String? { subject(id)?.name }

    @discardableResult
    func addSubject(name: String, icon: String, colorIndex: Int) -> Subject {
        let s = Subject(name: name, icon: icon, colorIndex: colorIndex)
        data.subjects.append(s)
        return s
    }

    func updateSubject(_ s: Subject) {
        guard let i = data.subjects.firstIndex(where: { $0.id == s.id }) else { return }
        data.subjects[i] = s
    }

    func deleteSubject(_ id: UUID) {
        let topicIDs = Set(data.topics.filter { $0.subjectID == id }.map { $0.id })
        data.topics.removeAll { $0.subjectID == id }
        data.notes.removeAll { $0.subjectID == id }
        let removedCards = Set(data.cards.filter { $0.subjectID == id }.map { $0.id })
        data.cards.removeAll { $0.subjectID == id }
        data.reviews.removeAll { removedCards.contains($0.cardID) }
        for i in data.tasks.indices where data.tasks[i].subjectID == id { data.tasks[i].subjectID = nil }
        for i in data.notes.indices { if let t = data.notes[i].topicID, topicIDs.contains(t) { data.notes[i].topicID = nil } }
        data.subjects.removeAll { $0.id == id }
        afterMutation()
    }

    func createStarterSubjects() {
        let starter: [(String, String, Int)] = [
            ("Математика", "function", 1), ("Информатика", "terminal", 2),
            ("Русский язык", "text.alignleft", 3), ("Физика", "atom", 4), ("Личное развитие", "scope", 0)
        ]
        for (n, i, c) in starter where !data.subjects.contains(where: { $0.name == n }) {
            data.subjects.append(Subject(name: n, icon: i, colorIndex: c))
        }
    }

    func saveTopic(_ t: Topic) {
        if let i = data.topics.firstIndex(where: { $0.id == t.id }) { data.topics[i] = t } else { data.topics.append(t) }
    }

    func deleteTopic(_ id: UUID) {
        data.topics.removeAll { $0.id == id }
        for i in data.notes.indices where data.notes[i].topicID == id { data.notes[i].topicID = nil }
        for i in data.cards.indices where data.cards[i].topicID == id { data.cards[i].topicID = nil }
    }

    // MARK: Заметки

    func note(_ id: UUID) -> Note? { data.notes.first { $0.id == id } }

    /// Создаёт или обновляет заметку. Пустые заметки не сохраняются.
    func saveNote(_ n: Note) {
        var note = n
        if let i = data.notes.firstIndex(where: { $0.id == n.id }) {
            if data.notes[i] == n { return }
            note.updatedAt = Date()
            data.notes[i] = note
        } else {
            guard !n.isEmpty else { return }
            note.updatedAt = Date()
            data.notes.append(note)
            award(key: "note:\(note.id.uuidString)", kind: .note, title: "Заметка: \(note.displayTitle)", amount: 0, showToast: false)
        }
        afterMutation()
    }

    func deleteNote(_ id: UUID) {
        data.notes.removeAll { $0.id == id }
    }

    // MARK: Карточки

    func card(_ id: UUID) -> Flashcard? { data.cards.first { $0.id == id } }

    func saveCard(_ c: Flashcard) {
        if let i = data.cards.firstIndex(where: { $0.id == c.id }) { data.cards[i] = c } else { data.cards.append(c) }
    }

    func deleteCard(_ id: UUID) {
        data.cards.removeAll { $0.id == id }
        data.reviews.removeAll { $0.cardID == id }
    }

    func dueCards(subjectID: UUID? = nil, now: Date = Date()) -> [Flashcard] {
        let limit = now.endOfDay
        return data.cards
            .filter { $0.dueDate < limit && (subjectID == nil || $0.subjectID == subjectID) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func reviewedToday() -> (count: Int, correct: Int) {
        let from = Date().startOfDay, to = from.addingDays(1)
        let logs = data.reviews.filter { $0.date >= from && $0.date < to }
        return (logs.count, logs.filter { $0.rating != .again }.count)
    }

    /// Применяет ответ пользователя. Возвращает начисленный XP.
    @discardableResult
    func review(cardID: UUID, rating: ReviewRating) -> Int {
        guard let i = data.cards.firstIndex(where: { $0.id == cardID }) else { return 0 }
        let now = Date()
        data.cards[i] = SRSService.apply(rating, to: data.cards[i], now: now)
        data.reviews.append(ReviewLog(cardID: cardID, date: now, rating: rating))
        if data.reviews.count > 20000 { data.reviews.removeFirst(data.reviews.count - 20000) }
        var xp = 0
        if rating != .again {
            let dayKey = Fmt.string(now, "yyyyMMdd")
            let from = now.startOfDay, to = from.addingDays(1)
            let earnedToday = data.events.filter { $0.kind == .cards && $0.date >= from && $0.date < to }.reduce(0) { $0 + $1.amount }
            if earnedToday < XPBalance.dailyCardCap {
                if award(key: "card:\(cardID.uuidString):\(dayKey)", kind: .cards, title: "Повторение карточки",
                         amount: XPBalance.cardXP, showToast: false) { xp = XPBalance.cardXP }
            }
        }
        afterMutation()
        return xp
    }

    func topicMastery(_ topic: Topic) -> Double {
        if topic.status == .mastered { return 1 }
        let cards = data.cards.filter { $0.topicID == topic.id }
        if cards.isEmpty { return 0 }
        return cards.reduce(0) { $0 + $1.mastery } / Double(cards.count)
    }

    func subjectMastery(_ id: UUID) -> Double {
        let cards = data.cards.filter { $0.subjectID == id }
        if cards.isEmpty { return 0 }
        return cards.reduce(0) { $0 + $1.mastery } / Double(cards.count)
    }

    // MARK: Фокус

    func subjectID(forTask id: UUID?) -> UUID? {
        guard let id = id else { return nil }
        return task(id)?.subjectID
    }

    @discardableResult
    func recordFocusSession(_ s: FocusSession) -> Int {
        guard !data.sessions.contains(where: { $0.id == s.id }) else { return 0 }
        data.sessions.append(s)
        var xp = 0
        if s.completed {
            xp = XPBalance.focusXP(minutes: s.actualSeconds / 60)
            award(key: "focus:\(s.id.uuidString)", kind: .focus, title: "Сессия фокуса, \(s.actualSeconds / 60) мин",
                  amount: xp, date: s.endedAt, showToast: false)
        }
        afterMutation()
        return xp
    }

    // MARK: Цели и привычки

    func saveGoal(_ g: Goal) {
        if let i = data.goals.firstIndex(where: { $0.id == g.id }) { data.goals[i] = g } else { data.goals.append(g) }
    }
    func deleteGoal(_ id: UUID) { data.goals.removeAll { $0.id == id } }

    func saveHabit(_ h: Habit) {
        if let i = data.habits.firstIndex(where: { $0.id == h.id }) { data.habits[i] = h } else { data.habits.append(h) }
        scheduleNotificationSync()
    }
    func deleteHabit(_ id: UUID) {
        data.habits.removeAll { $0.id == id }
        scheduleNotificationSync()
    }

    func toggleHabit(_ id: UUID, on day: Date) {
        guard let i = data.habits.firstIndex(where: { $0.id == id }) else { return }
        let d = day.startOfDay
        guard d <= Date().startOfDay else { return }
        let key = "habit:\(id.uuidString):\(Fmt.string(d, "yyyyMMdd"))"
        if let idx = data.habits[i].completions.firstIndex(of: d) {
            data.habits[i].completions.remove(at: idx)
            removeEvent(key: key)
        } else {
            data.habits[i].completions.append(d)
            if d == Date().startOfDay {
                award(key: key, kind: .habit, title: "Привычка: \(data.habits[i].title)", amount: XPBalance.habitXP)
            }
            Haptics.success()
        }
    }

    // MARK: Производные значения

    var totalXP: Int { data.events.reduce(0) { $0 + $1.amount } }
    var stats: StatsSnapshot { StatsService.snapshot(data) }

    func dayStats(_ day: Date = Date()) -> DayStats {
        let from = day.startOfDay, to = from.addingDays(1)
        return DayStats(tasksDone: StatsService.tasksDone(data, from: from, to: to),
                        focusMinutes: Int(StatsService.focusMinutes(data, from: from, to: to)),
                        xp: StatsService.xp(data, from: from, to: to),
                        taskGoal: data.settings.dailyTaskGoal,
                        focusGoal: data.settings.dailyFocusGoalMinutes)
    }

    func todayTasks() -> [TaskItem] {
        let now = Date()
        return data.tasks.filter { $0.isDueToday || $0.isOverdue(now: now) }
            .sorted {
                if $0.isDone != $1.isDone { return !$0.isDone }
                if $0.priority.rank != $1.priority.rank { return $0.priority.rank < $1.priority.rank }
                return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
    }

    func goalValue(_ g: Goal) -> Double { StatsService.goalValue(g, in: data) }

    var inboxCount: Int {
        let now = Date()
        let tasks = data.tasks.filter { !$0.isDone && ($0.isOverdue(now: now) || $0.isDueToday) }.count
        let habits = data.habits.filter { $0.isScheduled(now) && !$0.isDone(on: now) }.count
        return tasks + habits + (dueCards().isEmpty ? 0 : 1)
    }

    // MARK: Данные: сброс, замена, объединение

    func replaceAll(with newData: AppData) {
        var d = newData
        d.schemaVersion = AppData.currentSchema
        data = d
        flush()
        syncNotifications()
    }

    func merge(imported: AppData) {
        data = BackupService.merge(current: data, imported: imported)
        evaluateAchievements()
        flush()
        syncNotifications()
    }

    func resetAll() {
        NotificationService.cancelAll()
        data = AppData()
        flush()
    }
}
