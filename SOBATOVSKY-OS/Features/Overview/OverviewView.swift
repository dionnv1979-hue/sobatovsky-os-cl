import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var focus: FocusEngine
    @State private var showSettings = false
    @State private var showInbox = false
    @State private var showNewTask = false
    @State private var showGoals = false
    @State private var editingTask: TaskItem?

    private var greeting: String {
        let h = Calendar.sb.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Доброе утро."
        case 12..<18: return "Добрый день."
        case 18..<23: return "Добрый вечер."
        default: return "Доброй ночи."
        }
    }

    private func subtitle(_ ds: DayStats) -> String {
        if ds.progress >= 1 { return "Дневная цель выполнена. Отличная работа." }
        if ds.progress > 0 { return "Ты в движении. Осталось совсем немного до цели дня." }
        let phrases = ["Сегодня — хороший день, чтобы двигаться вперёд.",
                       "Один шаг сейчас — меньше забот потом.",
                       "Начни с самого важного.",
                       "Небольшой прогресс каждый день дороже рывка раз в месяц."]
        let day = Calendar.sb.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return phrases[day % phrases.count]
    }

    var body: some View {
        let ds = store.dayStats()
        let stats = store.stats
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    topBar
                    greetingBlock(ds)
                    if showOnboarding { onboardingCard }
                    progressCard(ds, stats)
                    levelCard(stats)
                    quickStats(ds, stats)
                    todayBlock
                    focusCard
                    goalsLink
                    activityBlock
                }
                .padding(.horizontal, SB.pad)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(SB.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showInbox) { InboxView() }
            .sheet(isPresented: $showNewTask) { TaskEditorView(task: nil) }
            .sheet(item: $editingTask) { t in TaskEditorView(task: t) }
            .sheet(isPresented: $showGoals) { GoalsHabitsView() }
        }
    }

    private var showOnboarding: Bool {
        !store.data.onboardingDismissed && store.data.tasks.isEmpty && store.data.subjects.isEmpty
    }

    // MARK: Блоки

    private var topBar: some View {
        HStack {
            Wordmark()
            Spacer()
            IconButton(system: "bell", label: "Напоминания", badge: store.inboxCount > 0) { showInbox = true }
            IconButton(system: "gearshape", label: "Настройки") { showSettings = true }
        }
    }

    private func greetingBlock(_ ds: DayStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting).font(.sb(14)).foregroundStyle(SB.silver)
            Text(Fmt.fullDate(Date()).uppercased()).font(.sb(11, .semibold)).tracking(1.2).foregroundStyle(SB.muted)
            Text("Твой день").font(.sb(34, .bold)).foregroundStyle(SB.white)
            Text(subtitle(ds)).font(.sb(15)).foregroundStyle(SB.silver)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var onboardingCard: some View {
        SBCard {
            VStack(alignment: .leading, spacing: 12) {
                SBLabel("НАЧАЛО РАБОТЫ")
                Text("Начни с первого шага").font(.sb(18, .semibold)).foregroundStyle(SB.white)
                Text("Добавь первую задачу или создай стартовый набор предметов для базы знаний.")
                    .font(.sb(14)).foregroundStyle(SB.silver)
                Button("Добавить задачу") { showNewTask = true }.buttonStyle(.sbPrimary)
                Button("Создать стартовые предметы") { store.createStarterSubjects() }.buttonStyle(.sbSecondary)
                Button("Скрыть") { store.data.onboardingDismissed = true }
                    .font(.sb(13)).foregroundStyle(SB.muted).frame(maxWidth: .infinity)
            }
        }
    }

    private func progressCard(_ ds: DayStats, _ stats: StatsSnapshot) -> some View {
        SBCard(radius: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    SBLabel("ПРОГРЕСС ДНЯ")
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 12))
                        Text("\(stats.currentStreak) \(Fmt.plural(stats.currentStreak, "день", "дня", "дней"))")
                            .font(.sb(12, .medium))
                    }
                    .foregroundStyle(stats.currentStreak > 0 ? SB.warning : SB.muted)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Серия: \(stats.currentStreak) дней")
                }
                HStack(spacing: 20) {
                    ZStack {
                        ProgressRing(progress: ds.progress, lineWidth: 10)
                        VStack(spacing: 2) {
                            Text("\(Int((ds.progress * 100).rounded()))%")
                                .font(.sb(30, .bold)).monospacedDigit().foregroundStyle(SB.white)
                            Text("цели дня").font(.sb(11)).foregroundStyle(SB.muted)
                        }
                    }
                    .frame(width: 124, height: 124)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Прогресс дня \(Int((ds.progress * 100).rounded())) процентов")

                    VStack(alignment: .leading, spacing: 12) {
                        metric("checklist", "\(ds.tasksDone) / \(ds.taskGoal)", "задач")
                        metric("timer", "\(ds.focusMinutes) / \(ds.focusGoal)", "мин фокуса")
                        metric("bolt.fill", "+\(ds.xp)", "XP за день")
                    }
                }
            }
        }
    }

    private func metric(_ icon: String, _ value: String, _ label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(SB.silver).frame(width: 18)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.sb(16, .semibold)).monospacedDigit().foregroundStyle(SB.white)
                Text(label).font(.sb(11)).foregroundStyle(SB.muted)
            }
        }
    }

    private func levelCard(_ stats: StatsSnapshot) -> some View {
        let p = LevelCurve.progress(for: stats.totalXP)
        return SBCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        SBLabel(String(format: "LEVEL %02d", p.level))
                        Text("Уровень \(p.level)").font(.sb(20, .bold)).foregroundStyle(SB.white)
                    }
                    Spacer()
                    Image(systemName: "star.circle.fill").font(.system(size: 28)).foregroundStyle(SB.silver)
                }
                LinearBar(value: p.needed > 0 ? Double(p.into) / Double(p.needed) : 0)
                HStack {
                    Text("\(Fmt.number(p.into)) / \(Fmt.number(p.needed)) XP").font(.sb(13, .medium)).monospacedDigit().foregroundStyle(SB.platinum)
                    Spacer()
                    Text("Всего \(Fmt.number(stats.totalXP)) XP").font(.sb(12)).foregroundStyle(SB.muted)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func quickStats(_ ds: DayStats, _ stats: StatsSnapshot) -> some View {
        HStack(spacing: 12) {
            StatTile(icon: "checklist", value: "\(ds.tasksDone)", label: "Задачи")
            StatTile(icon: "timer", value: "\(ds.focusMinutes)", label: "Фокус, мин")
            StatTile(icon: "flame.fill", value: "\(stats.currentStreak)", label: "Серия",
                     tint: stats.currentStreak > 0 ? SB.warning : SB.silver)
        }
    }

    private var todayBlock: some View {
        let tasks = store.todayTasks()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("На сегодня").font(.sb(20, .semibold)).foregroundStyle(SB.white)
                Spacer()
                Button("Все задачи") { Haptics.tap(); store.selectedTab = .tasks }
                    .font(.sb(14, .medium)).foregroundStyle(SB.silver)
                IconButton(system: "plus", label: "Новая задача") { showNewTask = true }
            }
            if tasks.isEmpty {
                SBCard {
                    EmptyState(icon: "checklist", title: "На сегодня задач нет",
                               message: "Добавь задачу и назначь ей срок на сегодня.",
                               buttonTitle: "Создать задачу") { showNewTask = true }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(tasks.prefix(5)) { t in
                        TaskRow(task: t, compact: true) { editingTask = t }
                    }
                }
            }
        }
    }

    private var focusCard: some View {
        let running = focus.isActive
        let secs = focus.remainingSeconds
        return SBCard(radius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                SBLabel("FOCUS SESSION")
                Text("Время сосредоточиться").font(.sb(20, .bold)).foregroundStyle(SB.white)
                Text(Fmt.clock(secs)).font(.sb(40, .bold)).monospacedDigit().foregroundStyle(SB.platinum)
                Text(running ? "Сессия идёт" : FocusMode.title(for: focus.state.modeID))
                    .font(.sb(13)).foregroundStyle(SB.silver)
                Button(running ? "Открыть фокус" : "Начать фокус") {
                    if focus.state.status == .idle { focus.start() }
                    store.selectedTab = .focus
                }
                .buttonStyle(.sbPrimary)
            }
        }
    }

    private var goalsLink: some View {
        Button { Haptics.tap(); showGoals = true } label: {
            SBCard(padding: 14, radius: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "scope").font(.system(size: 20)).foregroundStyle(SB.silver)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Цели и привычки").font(.sb(16, .semibold)).foregroundStyle(SB.white)
                        Text("\(store.data.goals.filter { !$0.isCompleted }.count) активных целей · \(store.data.habits.count) привычек")
                            .font(.sb(12)).foregroundStyle(SB.silver)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(SB.muted)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var activityBlock: some View {
        let items = Array(store.data.events.sorted { $0.date > $1.date }.prefix(6))
        return VStack(alignment: .leading, spacing: 12) {
            Text("Последняя активность").font(.sb(20, .semibold)).foregroundStyle(SB.white)
            if items.isEmpty {
                SBCard {
                    EmptyState(icon: "clock", title: "Пока тихо",
                               message: "Здесь появятся выполненные задачи, сессии фокуса и достижения.")
                }
            } else {
                SBCard(padding: 6) {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, e in
                            ActivityRow(event: e)
                            if idx < items.count - 1 { Divider().overlay(SB.border) }
                        }
                    }
                }
            }
        }
    }
}

struct ActivityRow: View {
    let event: XPEvent
    private var icon: String {
        switch event.kind {
        case .task: return "checkmark.circle"
        case .focus: return "timer"
        case .cards: return "rectangle.on.rectangle"
        case .note: return "note.text"
        case .habit: return "repeat"
        case .achievement: return "medal.fill"
        }
    }
    private var heading: String {
        switch event.kind {
        case .task: return "Задача выполнена"
        case .focus: return "Сессия фокуса"
        case .cards: return "Повторение"
        case .note: return "Создана заметка"
        case .habit: return "Привычка"
        case .achievement: return "Достижение"
        }
    }
    private var detail: String {
        switch event.kind {
        case .focus, .cards: return event.title
        case .achievement: return event.title.replacingOccurrences(of: "Достижение: ", with: "")
        case .habit: return event.title.replacingOccurrences(of: "Привычка: ", with: "")
        case .note: return event.title.replacingOccurrences(of: "Заметка: ", with: "")
        case .task: return event.title
        }
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(SB.silver).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(heading).font(.sb(14, .medium)).foregroundStyle(SB.white)
                Text(detail).font(.sb(12)).foregroundStyle(SB.silver).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if event.amount > 0 {
                    Text("+\(event.amount) XP").font(.sb(12, .semibold)).monospacedDigit().foregroundStyle(SB.platinum)
                }
                Text(Fmt.dueText(event.date, hasTime: true)).font(.sb(11)).foregroundStyle(SB.muted)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

struct InboxView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let now = Date()
        let overdue = store.data.tasks.filter { $0.isOverdue(now: now) }
        let today = store.data.tasks.filter { !$0.isDone && $0.isDueToday && !$0.isOverdue(now: now) }
        let habits = store.data.habits.filter { $0.isScheduled(now) && !$0.isDone(on: now) }
        let cards = store.dueCards().count
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if overdue.isEmpty && today.isEmpty && habits.isEmpty && cards == 0 {
                        SBCard { EmptyState(icon: "bell", title: "Всё спокойно",
                                            message: "Просроченных задач, привычек и карточек к повторению нет.") }
                    }
                    if !overdue.isEmpty {
                        group("Просрочено", overdue.map { ($0.title, "exclamationmark.circle", SB.error) })
                    }
                    if !today.isEmpty {
                        group("Сегодня", today.map { ($0.title, "calendar", SB.silver) })
                    }
                    if !habits.isEmpty {
                        group("Привычки сегодня", habits.map { ($0.title, "repeat", SB.silver) })
                    }
                    if cards > 0 {
                        group("Карточки", [("К повторению: \(cards)", "rectangle.on.rectangle", SB.silver)])
                    }
                }
                .padding(SB.pad)
            }
            .background(SB.background.ignoresSafeArea())
            .navigationTitle("Напоминания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }

    private func group(_ title: String, _ rows: [(String, String, Color)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SBLabel(title.uppercased())
            SBCard(padding: 6) {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { idx, r in
                        HStack(spacing: 12) {
                            Image(systemName: r.1).foregroundStyle(r.2).frame(width: 24)
                            Text(r.0).font(.sb(15)).foregroundStyle(SB.white).lineLimit(2)
                            Spacer()
                        }
                        .padding(10)
                        if idx < rows.count - 1 { Divider().overlay(SB.border) }
                    }
                }
            }
        }
    }
}
