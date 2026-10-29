import Foundation

// MARK: - Задачи

enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low, normal, high, critical
    var id: String { rawValue }
    var title: String {
        switch self {
        case .low: return "Низкий"
        case .normal: return "Обычный"
        case .high: return "Высокий"
        case .critical: return "Критический"
        }
    }
    var defaultXP: Int {
        switch self {
        case .low: return 5
        case .normal: return 10
        case .high: return 20
        case .critical: return 30
        }
    }
    var rank: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .normal: return 2
        case .low: return 3
        }
    }
}

enum RepeatRule: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly, monthly
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "Не повторять"
        case .daily: return "Каждый день"
        case .weekly: return "Каждую неделю"
        case .monthly: return "Каждый месяц"
        }
    }
    func next(after date: Date) -> Date {
        let c = Calendar.sb
        switch self {
        case .none: return date
        case .daily: return c.date(byAdding: .day, value: 1, to: date) ?? date
        case .weekly: return c.date(byAdding: .day, value: 7, to: date) ?? date
        case .monthly: return c.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }
}

enum TaskCategory {
    static let presets = ["Учёба", "Работа", "Личное", "Здоровье", "Проект"]
}

struct TaskItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var details = ""
    var dueDate: Date?
    var hasTime = false
    var priority: TaskPriority = .normal
    var category = ""
    var subjectID: UUID?
    var estimatedMinutes = 0
    var reminder = false
    var repeatRule: RepeatRule = .none
    var xp = 10
    var isDone = false
    var completedAt: Date?
    var createdAt = Date()
    var spawnedNextID: UUID?

    func isOverdue(now: Date = Date()) -> Bool {
        guard !isDone, let d = dueDate else { return false }
        return hasTime ? d < now : d.startOfDay < now.startOfDay
    }
    var isDueToday: Bool { dueDate?.isToday ?? false }
}

// MARK: - Знания

struct Subject: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var icon = "book.closed"
    var colorIndex = 0
    var createdAt = Date()
}

enum TopicStatus: String, Codable, CaseIterable, Identifiable {
    case notStarted, learning, mastered, needsReview
    var id: String { rawValue }
    var title: String {
        switch self {
        case .notStarted: return "Не начата"
        case .learning: return "Изучается"
        case .mastered: return "Освоена"
        case .needsReview: return "Нужно повторить"
        }
    }
}

struct Topic: Identifiable, Codable, Equatable {
    var id = UUID()
    var subjectID: UUID
    var name: String
    var details = ""
    var status: TopicStatus = .notStarted
    var createdAt = Date()
}

struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var title = ""
    var body = ""
    var subjectID: UUID?
    var topicID: UUID?
    var tags: [String] = []
    var isPinned = false
    var createdAt = Date()
    var updatedAt = Date()
    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        let first = body.split(separator: "\n").first.map(String.init) ?? ""
        return first.isEmpty ? "Без названия" : String(first.prefix(60))
    }
}

enum CardDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard
    var id: String { rawValue }
    var title: String {
        switch self {
        case .easy: return "Лёгкая"
        case .medium: return "Средняя"
        case .hard: return "Сложная"
        }
    }
}

enum ReviewRating: String, Codable, CaseIterable, Identifiable {
    case again, hard, good, easy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .again: return "Не помню"
        case .hard: return "Сложно"
        case .good: return "Помню"
        case .easy: return "Легко"
        }
    }
}

struct Flashcard: Identifiable, Codable, Equatable {
    var id = UUID()
    var question: String
    var answer: String
    var subjectID: UUID?
    var topicID: UUID?
    var difficulty: CardDifficulty = .medium
    var dueDate = Date()
    var intervalDays: Double = 0
    var ease: Double = 2.5
    var repetitions = 0
    var correctCount = 0
    var wrongCount = 0
    var lastReviewed: Date?
    var createdAt = Date()

    /// Освоение карточки 0…1 по числу успешных повторений подряд.
    var mastery: Double { min(1, Double(repetitions) / 4.0) }
}

struct ReviewLog: Identifiable, Codable, Equatable {
    var id = UUID()
    var cardID: UUID
    var date = Date()
    var rating: ReviewRating
}

// MARK: - Фокус

struct FocusSession: Identifiable, Codable, Equatable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date
    var plannedSeconds: Int
    var actualSeconds: Int
    var completed: Bool
    var taskID: UUID?
    var subjectID: UUID?
    var modeID: String

    /// Прерванные сессии короче 5 минут в статистику минут не попадают.
    var countedMinutes: Double {
        (completed || actualSeconds >= 300) ? Double(actualSeconds) / 60.0 : 0
    }
}

// MARK: - Цели и привычки

enum GoalKind: String, Codable, CaseIterable, Identifiable {
    case focusMinutes, tasksDone, sessions, cardsReviewed, manual
    var id: String { rawValue }
    var title: String {
        switch self {
        case .focusMinutes: return "Минуты фокуса"
        case .tasksDone: return "Выполненные задачи"
        case .sessions: return "Сессии фокуса"
        case .cardsReviewed: return "Повторения карточек"
        case .manual: return "Вручную"
        }
    }
    var unit: String {
        switch self {
        case .focusMinutes: return "мин"
        case .tasksDone: return "задач"
        case .sessions: return "сессий"
        case .cardsReviewed: return "повторений"
        case .manual: return ""
        }
    }
}

struct Goal: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var details = ""
    var kind: GoalKind = .tasksDone
    var target: Double = 10
    var manualValue: Double = 0
    var subjectID: UUID?
    var startDate = Date().startOfDay
    var deadline: Date?
    var isCompleted = false
    var createdAt = Date()
}

enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
    case daily, weekdays
    var id: String { rawValue }
    var title: String { self == .daily ? "Каждый день" : "По будням" }
}

struct Habit: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var frequency: HabitFrequency = .daily
    var reminderEnabled = false
    var reminderHour = 20
    var reminderMinute = 0
    var completions: [Date] = []
    var createdAt = Date()

    func isScheduled(_ day: Date) -> Bool {
        frequency == .daily || !Calendar.sb.isDateInWeekend(day)
    }
    func isDone(on day: Date) -> Bool { completions.contains(day.startOfDay) }

    func streak(today: Date = Date()) -> Int {
        var cursor = today.startOfDay
        if isScheduled(cursor) && !isDone(on: cursor) { cursor = cursor.addingDays(-1) }
        var count = 0
        var steps = 0
        while steps < 3660 {
            steps += 1
            if !isScheduled(cursor) { cursor = cursor.addingDays(-1); continue }
            if isDone(on: cursor) { count += 1; cursor = cursor.addingDays(-1) } else { break }
        }
        return count
    }

    func completionRate(days: Int = 30, today: Date = Date()) -> Double {
        let end = today.startOfDay
        let start = max(createdAt.startOfDay, end.addingDays(-(days - 1)))
        var scheduled = 0, done = 0
        var d = start
        while d <= end {
            if isScheduled(d) { scheduled += 1; if isDone(on: d) { done += 1 } }
            d = d.addingDays(1)
        }
        return scheduled == 0 ? 0 : Double(done) / Double(scheduled)
    }
}

// MARK: - XP, достижения

enum EventKind: String, Codable {
    case task, focus, cards, note, habit, achievement
}

struct XPEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    var key: String
    var kind: EventKind
    var title: String
    var amount: Int
    var date = Date()
}

struct AchievementRecord: Identifiable, Codable, Equatable {
    var id: String
    var unlockedAt: Date
}

// MARK: - Настройки

enum ThemeChoice: String, Codable, CaseIterable, Identifiable {
    case dark, light, system
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dark: return "Тёмная"
        case .light: return "Светлая"
        case .system: return "Системная"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var theme: ThemeChoice = .dark
    var animations = true
    var xpToast = true
    var haptics = true
    var customWorkMinutes = 30
    var customRestMinutes = 5
    var focusSound = true
    var focusNotifications = true
    var dailyFocusGoalMinutes = 60
    var dailyTaskGoal = 3
    var taskReminders = true
    var cardReminderEnabled = false
    var cardReminderHour = 19

    init() {}

    enum CodingKeys: String, CodingKey {
        case theme, animations, xpToast, haptics, customWorkMinutes, customRestMinutes, focusSound
        case focusNotifications, dailyFocusGoalMinutes, dailyTaskGoal, taskReminders
        case cardReminderEnabled, cardReminderHour
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v<T: Decodable>(_ k: CodingKeys, _ d: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? d }
        theme = v(.theme, theme)
        animations = v(.animations, animations)
        xpToast = v(.xpToast, xpToast)
        haptics = v(.haptics, haptics)
        customWorkMinutes = v(.customWorkMinutes, customWorkMinutes)
        customRestMinutes = v(.customRestMinutes, customRestMinutes)
        focusSound = v(.focusSound, focusSound)
        focusNotifications = v(.focusNotifications, focusNotifications)
        dailyFocusGoalMinutes = v(.dailyFocusGoalMinutes, dailyFocusGoalMinutes)
        dailyTaskGoal = v(.dailyTaskGoal, dailyTaskGoal)
        taskReminders = v(.taskReminders, taskReminders)
        cardReminderEnabled = v(.cardReminderEnabled, cardReminderEnabled)
        cardReminderHour = v(.cardReminderHour, cardReminderHour)
    }
}

// MARK: - Контейнер всех данных

struct AppData: Codable, Equatable {
    static let currentSchema = 1

    var schemaVersion = AppData.currentSchema
    var tasks: [TaskItem] = []
    var subjects: [Subject] = []
    var topics: [Topic] = []
    var notes: [Note] = []
    var cards: [Flashcard] = []
    var reviews: [ReviewLog] = []
    var sessions: [FocusSession] = []
    var goals: [Goal] = []
    var habits: [Habit] = []
    var achievements: [AchievementRecord] = []
    var events: [XPEvent] = []
    var settings = AppSettings()
    var onboardingDismissed = false

    init() {}

    enum CodingKeys: String, CodingKey {
        case schemaVersion, tasks, subjects, topics, notes, cards, reviews, sessions
        case goals, habits, achievements, events, settings, onboardingDismissed
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? AppData.currentSchema
        tasks = try c.decodeIfPresent([TaskItem].self, forKey: .tasks) ?? []
        subjects = try c.decodeIfPresent([Subject].self, forKey: .subjects) ?? []
        topics = try c.decodeIfPresent([Topic].self, forKey: .topics) ?? []
        notes = try c.decodeIfPresent([Note].self, forKey: .notes) ?? []
        cards = try c.decodeIfPresent([Flashcard].self, forKey: .cards) ?? []
        reviews = try c.decodeIfPresent([ReviewLog].self, forKey: .reviews) ?? []
        sessions = try c.decodeIfPresent([FocusSession].self, forKey: .sessions) ?? []
        goals = try c.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        habits = try c.decodeIfPresent([Habit].self, forKey: .habits) ?? []
        achievements = try c.decodeIfPresent([AchievementRecord].self, forKey: .achievements) ?? []
        events = try c.decodeIfPresent([XPEvent].self, forKey: .events) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        onboardingDismissed = try c.decodeIfPresent(Bool.self, forKey: .onboardingDismissed) ?? false
    }
}
