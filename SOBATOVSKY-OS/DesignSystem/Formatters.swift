import Foundation

extension Calendar {
    /// Григорианский календарь, неделя с понедельника, актуальный часовой пояс.
    static let sb: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ru_RU")
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        c.timeZone = TimeZone.autoupdatingCurrent
        return c
    }()
}

extension Date {
    var startOfDay: Date { Calendar.sb.startOfDay(for: self) }
    var endOfDay: Date { startOfDay.addingDays(1) }
    var isToday: Bool { Calendar.sb.isDateInToday(self) }
    func addingDays(_ n: Int) -> Date { Calendar.sb.date(byAdding: .day, value: n, to: self) ?? self }
    func isSameDay(as other: Date) -> Bool { Calendar.sb.isDate(self, inSameDayAs: other) }
    var startOfWeek: Date {
        let c = Calendar.sb
        return c.date(from: c.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)) ?? startOfDay
    }
}

enum Fmt {
    static let locale = Locale(identifier: "ru_RU")
    private static var cache: [String: DateFormatter] = [:]

    static func string(_ date: Date, _ format: String) -> String {
        let f: DateFormatter
        if let cached = cache[format] { f = cached } else {
            f = DateFormatter()
            f.locale = locale
            f.dateFormat = format
            cache[format] = f
        }
        f.timeZone = TimeZone.autoupdatingCurrent
        return f.string(from: date)
    }

    static func fullDate(_ d: Date) -> String {
        let s = string(d, "EEEE, d MMMM")
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    static func dayTitle(_ d: Date, now: Date = Date()) -> String {
        let diff = Calendar.sb.dateComponents([.day], from: now.startOfDay, to: d.startOfDay).day ?? 0
        switch diff {
        case 0: return "Сегодня"
        case 1: return "Завтра"
        case -1: return "Вчера"
        default: return string(d, "d MMM")
        }
    }

    static func dueText(_ d: Date, hasTime: Bool) -> String {
        hasTime ? "\(dayTitle(d)), \(string(d, "HH:mm"))" : dayTitle(d)
    }

    static func number(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "\u{00A0}"
        f.usesGroupingSeparator = true
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    static func minutes(_ m: Int) -> String {
        if m < 60 { return "\(m) мин" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h) ч" : "\(h) ч \(r) мин"
    }

    static func clock(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    static func plural(_ n: Int, _ one: String, _ few: String, _ many: String) -> String {
        let a = abs(n) % 100, b = a % 10
        if a > 10 && a < 20 { return many }
        if b > 1 && b < 5 { return few }
        if b == 1 { return one }
        return many
    }
}
