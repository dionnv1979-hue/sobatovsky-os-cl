import Foundation

/// Баланс наград вынесен в одно место.
enum XPBalance {
    static func taskXP(for priority: TaskPriority) -> Int { priority.defaultXP }
    /// 1 XP за минуту, но не больше 120 за сессию.
    static func focusXP(minutes: Int) -> Int { min(120, max(1, minutes)) }
    static let cardXP = 1
    static let dailyCardCap = 30
    static let habitXP = 3
    static let achievementBonus = 25
}

/// Прозрачная детерминированная кривая уровней:
/// переход с уровня k на k+1 стоит 50·k + 50 XP, поэтому XP начала уровня n = 25·(n−1)·(n+2).
enum LevelCurve {
    static func xpStart(ofLevel n: Int) -> Int { 25 * max(0, n - 1) * (n + 2) }

    static func level(for xp: Int) -> Int {
        var n = 1
        while xpStart(ofLevel: n + 1) <= xp { n += 1 }
        return n
    }

    /// (уровень, XP внутри уровня, XP, нужный для следующего уровня)
    static func progress(for xp: Int) -> (level: Int, into: Int, needed: Int) {
        let l = level(for: max(0, xp))
        let start = xpStart(ofLevel: l)
        let needed = xpStart(ofLevel: l + 1) - start
        return (l, max(0, xp) - start, needed)
    }
}
