import Foundation
import UserNotifications
import UIKit

/// Локальные уведомления. Разрешение запрашивается только когда оно действительно нужно.
enum NotificationService {
    private static var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    static func status(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { s in
            DispatchQueue.main.async { completion(s.authorizationStatus) }
        }
    }

    /// Запрашивает разрешение, если оно ещё не запрашивалось. Возвращает, можно ли отправлять уведомления.
    static func requestIfNeeded(_ completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { s in
            switch s.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion(true) }
            case .denied:
                DispatchQueue.main.async { completion(false) }
            default:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    DispatchQueue.main.async { completion(granted) }
                }
            }
        }
    }

    static func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    private static func content(_ title: String, _ body: String) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        return c
    }

    private static func removePending(prefix: String, then add: @escaping () -> Void) {
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            add()
        }
    }

    // MARK: Задачи

    static func syncTasks(_ tasks: [TaskItem], enabled: Bool) {
        let now = Date()
        var items: [(String, Date, String)] = []
        if enabled {
            for t in tasks where !t.isDone && t.reminder {
                guard let due = t.dueDate else { continue }
                var fire = due
                if !t.hasTime {
                    fire = Calendar.sb.date(bySettingHour: 9, minute: 0, second: 0, of: due) ?? due
                }
                if fire > now { items.append(("task-\(t.id.uuidString)", fire, t.title)) }
            }
        }
        items.sort { $0.1 < $1.1 }
        let limited = Array(items.prefix(40))
        removePending(prefix: "task-") {
            for (id, date, title) in limited {
                let comps = Calendar.sb.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: id, content: content("Задача", title), trigger: trigger))
            }
        }
    }

    // MARK: Привычки

    static func syncHabits(_ habits: [Habit]) {
        let active = habits.filter { $0.reminderEnabled }.prefix(8)
        removePending(prefix: "habit-") {
            for h in active {
                let weekdays: [Int?] = h.frequency == .daily ? [nil] : [2, 3, 4, 5, 6]
                for wd in weekdays {
                    var comps = DateComponents()
                    comps.hour = h.reminderHour
                    comps.minute = h.reminderMinute
                    if let wd = wd { comps.weekday = wd }
                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                    let id = "habit-\(h.id.uuidString)-\(wd ?? 0)"
                    center.add(UNNotificationRequest(identifier: id, content: content("Привычка", h.title), trigger: trigger))
                }
            }
        }
    }

    // MARK: Карточки

    static func syncCardReminder(enabled: Bool, hour: Int) {
        removePending(prefix: "cards-") {
            guard enabled else { return }
            var comps = DateComponents()
            comps.hour = hour
            comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: "cards-daily",
                                             content: content("Повторение", "Загляни в SOBATOVSKY OS: пора повторить карточки."),
                                             trigger: trigger))
        }
    }

    // MARK: Фокус

    static func scheduleFocusEnd(at date: Date, title: String, body: String) {
        guard date.timeIntervalSinceNow > 1 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: date.timeIntervalSinceNow, repeats: false)
        center.removePendingNotificationRequests(withIdentifiers: ["focus-end"])
        center.add(UNNotificationRequest(identifier: "focus-end", content: content(title, body), trigger: trigger))
    }

    static func cancelFocusEnd() {
        center.removePendingNotificationRequests(withIdentifiers: ["focus-end"])
    }

    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
