import Foundation

/// Простое интервальное повторение (упрощённый SM-2).
enum SRSService {
    static func apply(_ rating: ReviewRating, to card: Flashcard, now: Date = Date()) -> Flashcard {
        var c = card
        switch rating {
        case .again:
            c.repetitions = 0
            c.intervalDays = 0
            c.ease = max(1.3, c.ease - 0.2)
            c.wrongCount += 1
            c.dueDate = now.addingTimeInterval(10 * 60)
        case .hard:
            let i = c.repetitions == 0 ? 1.0 : max(1, c.intervalDays * 1.2)
            c.intervalDays = i.rounded()
            c.ease = max(1.3, c.ease - 0.15)
            c.repetitions += 1
            c.correctCount += 1
            c.dueDate = now.startOfDay.addingDays(Int(c.intervalDays))
        case .good:
            let i: Double
            switch c.repetitions {
            case 0: i = 1
            case 1: i = 3
            default: i = max(c.intervalDays + 1, c.intervalDays * c.ease)
            }
            c.intervalDays = i.rounded()
            c.repetitions += 1
            c.correctCount += 1
            c.dueDate = now.startOfDay.addingDays(Int(c.intervalDays))
        case .easy:
            let i = c.repetitions == 0 ? 3.0 : max(c.intervalDays + 2, c.intervalDays * c.ease * 1.3)
            c.intervalDays = i.rounded()
            c.ease = c.ease + 0.15
            c.repetitions += 1
            c.correctCount += 1
            c.dueDate = now.startOfDay.addingDays(Int(c.intervalDays))
        }
        c.lastReviewed = now
        return c
    }

    static func hint(_ rating: ReviewRating, for card: Flashcard, now: Date = Date()) -> String {
        if rating == .again { return "10 мин" }
        let next = apply(rating, to: card, now: now)
        let d = Calendar.sb.dateComponents([.day], from: now.startOfDay, to: next.dueDate.startOfDay).day ?? 1
        return "\(max(1, d)) дн."
    }
}
