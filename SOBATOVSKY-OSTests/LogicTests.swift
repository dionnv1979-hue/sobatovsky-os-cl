import XCTest
@testable import SOBATOVSKY_OS

final class LogicTests: XCTestCase {
    func testLevelCurve() {
        XCTAssertEqual(LevelCurve.level(for: 0), 1)
        XCTAssertEqual(LevelCurve.level(for: 99), 1)
        XCTAssertEqual(LevelCurve.xpStart(ofLevel: 2), 100)
        XCTAssertEqual(LevelCurve.level(for: 100), 2)
        XCTAssertEqual(LevelCurve.xpStart(ofLevel: 3), 250)
        let p = LevelCurve.progress(for: 130)
        XCTAssertEqual(p.level, 2)
        XCTAssertEqual(p.into, 30)
        XCTAssertEqual(p.needed, 150)
    }

    func testSRSIntervals() {
        var c = Flashcard(question: "q", answer: "a")
        let now = Date()
        c = SRSService.apply(.good, to: c, now: now)
        XCTAssertEqual(c.intervalDays, 1)
        c = SRSService.apply(.good, to: c, now: now)
        XCTAssertEqual(c.intervalDays, 3)
        c = SRSService.apply(.good, to: c, now: now)
        XCTAssertEqual(c.intervalDays, 8)
        XCTAssertEqual(c.correctCount, 3)
        c = SRSService.apply(.again, to: c, now: now)
        XCTAssertEqual(c.repetitions, 0)
        XCTAssertEqual(c.wrongCount, 1)
        XCTAssertTrue(c.dueDate > now)
    }

    func testStreaks() {
        let today = Date().startOfDay
        let days: Set<Date> = [today, today.addingDays(-1), today.addingDays(-2), today.addingDays(-5)]
        let s = StatsService.streaks(days: days, today: Date())
        XCTAssertEqual(s.current, 3)
        XCTAssertEqual(s.max, 3)
        let yesterdayOnly: Set<Date> = [today.addingDays(-1)]
        XCTAssertEqual(StatsService.streaks(days: yesterdayOnly, today: Date()).current, 1)
        XCTAssertEqual(StatsService.streaks(days: [], today: Date()).current, 0)
    }

    func testBackupRoundTripAndMerge() throws {
        var d = AppData()
        d.tasks.append(TaskItem(title: "A"))
        d.subjects.append(Subject(name: "Математика"))
        let raw = try BackupService.export(d)
        let parsed = try BackupService.parse(raw)
        XCTAssertEqual(parsed.data.tasks.count, 1)
        let merged = BackupService.merge(current: d, imported: parsed.data)
        XCTAssertEqual(merged.tasks.count, 1)
        XCTAssertThrowsError(try BackupService.parse(Data("{}".utf8)))
    }

    func testXPAwardedOnce() {
        let store = AppStore()
        store.resetAll()
        let t = TaskItem(title: "T", xp: 10)
        store.addTask(t)
        store.toggleTask(t.id)
        store.toggleTask(t.id)   // отмена
        store.toggleTask(t.id)   // снова
        let taskEvents = store.data.events.filter { $0.key == "task:\(t.id.uuidString)" }
        XCTAssertEqual(taskEvents.count, 1)
        store.resetAll()
    }
}
