import Foundation

struct AchievementDef: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let goal: Int
    let current: (StatsSnapshot) -> Int
}

enum AchievementCatalog {
    static let all: [AchievementDef] = [
        AchievementDef(id: "first_task", title: "Первый шаг", detail: "Выполни первую задачу", icon: "checkmark.circle", goal: 1, current: { $0.tasksDone }),
        AchievementDef(id: "first_session", title: "Концентрация", detail: "Заверши первую сессию фокуса", icon: "timer", goal: 1, current: { $0.completedSessions }),
        AchievementDef(id: "focus_hour", title: "Час фокуса", detail: "Накопи 60 минут фокуса", icon: "hourglass", goal: 60, current: { $0.focusMinutes }),
        AchievementDef(id: "ten_wins", title: "Десять побед", detail: "Выполни 10 задач", icon: "checklist", goal: 10, current: { $0.tasksDone }),
        AchievementDef(id: "streak_3", title: "Учёба каждый день", detail: "Серия активности — 3 дня подряд", icon: "flame.fill", goal: 3, current: { $0.maxStreak }),
        AchievementDef(id: "first_note", title: "Архив знаний", detail: "Создай первую заметку", icon: "note.text", goal: 1, current: { $0.notes }),
        AchievementDef(id: "first_review", title: "Память", detail: "Повтори карточку первый раз", icon: "rectangle.on.rectangle", goal: 1, current: { $0.reviewsTotal }),
        AchievementDef(id: "seven_days", title: "Системный подход", detail: "7 активных дней", icon: "calendar", goal: 7, current: { $0.activeDays }),
        AchievementDef(id: "focus_master", title: "Мастер фокуса", detail: "Заверши 25 сессий фокуса", icon: "medal.fill", goal: 25, current: { $0.completedSessions })
    ]
}
