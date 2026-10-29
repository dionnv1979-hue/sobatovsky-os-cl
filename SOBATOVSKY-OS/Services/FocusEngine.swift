import Foundation
import SwiftUI
import AudioToolbox
import UIKit

enum FocusPhase: String, Codable { case work, rest }
enum FocusStatus: String, Codable { case idle, running, paused, finished }

struct FocusMode: Identifiable, Hashable {
    let id: String
    let title: String
    static let all: [FocusMode] = [
        FocusMode(id: "pomodoro", title: "Pomodoro"),
        FocusMode(id: "deep", title: "Deep Focus"),
        FocusMode(id: "short", title: "Короткая"),
        FocusMode(id: "custom", title: "Своя")
    ]
    static func title(for id: String) -> String { all.first { $0.id == id }?.title ?? "Фокус" }
}

struct FocusPersisted: Codable, Equatable {
    var modeID = "pomodoro"
    var phase: FocusPhase = .work
    var status: FocusStatus = .idle
    var sessionID = UUID()
    var startedAt = Date()
    var endDate: Date?
    var remaining: Double = 0
    var total: Double = 0
    var workMinutes = 25
    var restMinutes = 5
    var taskID: UUID?
}

struct FocusResult: Equatable {
    var sessionID: UUID
    var minutes: Int
    var xp: Int
    var taskID: UUID?
    var hasRest: Bool
}

/// Таймер фокуса. Хранит время начала/окончания и считает остаток по системным часам,
/// поэтому корректно переживает блокировку экрана, сворачивание и перезапуск приложения.
final class FocusEngine: ObservableObject {
    @Published private(set) var state: FocusPersisted
    @Published private(set) var now = Date()
    @Published var result: FocusResult?

    weak var store: AppStore?
    private var timer: Timer?
    private let key = "focus.state.v1"

    init() {
        if let raw = UserDefaults.standard.data(forKey: "focus.state.v1"),
           var s = try? JSONDecoder().decode(FocusPersisted.self, from: raw) {
            if s.status == .finished { s.status = .idle; s.endDate = nil }
            state = s
        } else {
            state = FocusPersisted()
        }
    }

    deinit { timer?.invalidate() }

    func attach(_ store: AppStore) {
        self.store = store
        tick()
        startTimerIfNeeded()
    }

    // MARK: Параметры

    func durations(for modeID: String) -> (work: Int, rest: Int) {
        switch modeID {
        case "pomodoro": return (25, 5)
        case "deep": return (50, 10)
        case "short": return (15, 0)
        default:
            let s = store?.data.settings
            return (s?.customWorkMinutes ?? 30, s?.customRestMinutes ?? 5)
        }
    }

    var remainingSeconds: Double {
        switch state.status {
        case .running:
            guard let e = state.endDate else { return state.remaining }
            return max(0, min(state.total, e.timeIntervalSince(now)))
        case .paused: return state.remaining
        case .finished: return 0
        case .idle: return Double(durations(for: state.modeID).work * 60)
        }
    }

    var fraction: Double {
        guard state.status != .idle, state.total > 0 else { return 0 }
        if state.status == .finished { return 1 }
        return min(1, max(0, 1 - remainingSeconds / state.total))
    }

    var isActive: Bool { state.status == .running || state.status == .paused }

    // MARK: Выбор (только в покое)

    func selectMode(_ id: String) {
        guard state.status == .idle else { return }
        state.modeID = id
        persist()
    }

    func selectTask(_ id: UUID?) {
        guard state.status == .idle else { return }
        state.taskID = id
        persist()
    }

    // MARK: Управление

    func start() {
        guard state.status == .idle else { return }
        let d = durations(for: state.modeID)
        let t = Double(d.work * 60)
        let start = Date()
        state.sessionID = UUID()
        state.startedAt = start
        state.phase = .work
        state.workMinutes = d.work
        state.restMinutes = d.rest
        state.total = t
        state.remaining = t
        state.endDate = start.addingTimeInterval(t)
        state.status = .running
        now = start
        persist()
        startTimerIfNeeded()
        scheduleEndNotification()
        Haptics.tap()
    }

    func pause() {
        guard state.status == .running else { return }
        let rem = remainingSeconds
        now = Date()
        state.remaining = max(0, min(state.total, state.endDate.map { $0.timeIntervalSince(now) } ?? rem))
        state.endDate = nil
        state.status = .paused
        persist()
        NotificationService.cancelFocusEnd()
        Haptics.tap()
    }

    func resume() {
        guard state.status == .paused else { return }
        now = Date()
        state.endDate = now.addingTimeInterval(state.remaining)
        state.status = .running
        persist()
        startTimerIfNeeded()
        scheduleEndNotification()
        Haptics.tap()
    }

    /// Завершить раньше времени: сессия сохраняется как незавершённая (без XP), если прошло не меньше минуты.
    func finishEarly() {
        guard state.phase == .work, isActive else { return }
        now = Date()
        let elapsed = max(0, state.total - remainingSeconds)
        if elapsed >= 60 {
            let s = FocusSession(id: state.sessionID, startedAt: state.startedAt, endedAt: now,
                                 plannedSeconds: Int(state.total), actualSeconds: Int(elapsed), completed: false,
                                 taskID: state.taskID, subjectID: store?.subjectID(forTask: state.taskID),
                                 modeID: state.modeID)
            store?.recordFocusSession(s)
        }
        resetToIdle()
    }

    /// Сбросить без сохранения.
    func reset() {
        resetToIdle()
    }

    func skipRest() { resetToIdle() }

    func continueAfterWork() {
        guard let r = result else { return }
        result = nil
        if r.hasRest && state.restMinutes > 0 {
            let t = Double(state.restMinutes * 60)
            let n = Date()
            state.phase = .rest
            state.total = t
            state.remaining = t
            state.endDate = n.addingTimeInterval(t)
            state.status = .running
            now = n
            persist()
            startTimerIfNeeded()
            scheduleEndNotification()
        } else {
            resetToIdle()
        }
    }

    func dismissResult() {
        result = nil
        resetToIdle()
    }

    // MARK: Тик

    func tick() {
        now = Date()
        guard state.status == .running, let e = state.endDate else { return }
        if e <= now {
            if state.phase == .work { completeWork(at: e) } else { completeRest() }
        }
    }

    private func completeWork(at end: Date) {
        let secs = Int(state.total)
        let session = FocusSession(id: state.sessionID, startedAt: state.startedAt, endedAt: end,
                                   plannedSeconds: secs, actualSeconds: secs, completed: true,
                                   taskID: state.taskID, subjectID: store?.subjectID(forTask: state.taskID),
                                   modeID: state.modeID)
        let xp = store?.recordFocusSession(session) ?? 0
        state.status = .finished
        state.endDate = nil
        state.remaining = 0
        result = FocusResult(sessionID: state.sessionID, minutes: secs / 60, xp: xp,
                             taskID: state.taskID, hasRest: state.restMinutes > 0)
        stopTimer()
        persist()
        notifyFinished()
    }

    private func completeRest() {
        resetToIdle()
        notifyFinished()
    }

    private func notifyFinished() {
        Haptics.success()
        let soundOn = store?.data.settings.focusSound ?? true
        if soundOn && UIApplication.shared.applicationState == .active {
            AudioServicesPlaySystemSound(1007)
        }
    }

    private func resetToIdle() {
        stopTimer()
        NotificationService.cancelFocusEnd()
        state.status = .idle
        state.phase = .work
        state.endDate = nil
        state.remaining = 0
        state.total = 0
        persist()
    }

    // MARK: Служебное

    private func scheduleEndNotification() {
        guard store?.data.settings.focusNotifications ?? false, let end = state.endDate else { return }
        let isWork = state.phase == .work
        NotificationService.requestIfNeeded { granted in
            guard granted else { return }
            NotificationService.scheduleFocusEnd(
                at: end,
                title: isWork ? "Сессия завершена" : "Отдых закончен",
                body: isWork ? "Отличная работа. Открой SOBATOVSKY OS, чтобы забрать XP." : "Можно начинать новую сессию.")
        }
    }

    private func startTimerIfNeeded() {
        guard timer == nil, state.status == .running else { return }
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func persist() {
        if let raw = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(raw, forKey: key)
        }
    }
}
