import SwiftUI
import Charts

enum ProgressPeriod: String, CaseIterable, Hashable {
    case week, month, all
    var title: String {
        switch self {
        case .week: return "7 дней"
        case .month: return "30 дней"
        case .all: return "Всё время"
        }
    }
}

struct SubjectMinutes: Identifiable {
    let id = UUID()
    let name: String
    let minutes: Double
}

struct ChartBucket: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct ProgressScreen: View {
    @EnvironmentObject var store: AppStore
    @State private var period: ProgressPeriod = .week
    @State private var showGoals = false
    @State private var showAchievements = false

    /// Начало периода для сводных показателей.
    private var rangeStart: Date {
        switch period {
        case .week: return Date().startOfDay.addingDays(-6)
        case .month: return Date().startOfDay.addingDays(-29)
        case .all: return .distantPast
        }
    }

    /// Интервалы для графиков: дни (7/30) либо недели (последние 12) для «всё время».
    private var bucketStarts: [Date] {
        let today = Date().startOfDay
        switch period {
        case .week: return (0..<7).map { today.addingDays($0 - 6) }
        case .month: return (0..<30).map { today.addingDays($0 - 29) }
        case .all:
            let w = Date().startOfWeek
            return (0..<12).map { w.addingDays(($0 - 11) * 7) }
        }
    }
    private var bucketDays: Int { period == .all ? 7 : 1 }

    private func buckets(_ f: (Date, Date) -> Double) -> [ChartBucket] {
        bucketStarts.map { ChartBucket(date: $0, value: f($0, $0.addingDays(bucketDays))) }
    }

    var body: some View {
        let to = Date().endOfDay
        let from = rangeStart
        let d = store.data
        let stats = store.stats
        let p = LevelCurve.progress(for: stats.totalXP)
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ScreenHeader("Прогресс", subtitle: "Результат складывается из действий.")
                    FilterChips(items: ProgressPeriod.allCases, selection: $period) { $0.title }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        StatTile(icon: "hourglass", value: Fmt.minutes(Int(StatsService.focusMinutes(d, from: from, to: to))), label: "Минут фокуса")
                        StatTile(icon: "checklist", value: "\(StatsService.tasksDone(d, from: from, to: to))", label: "Задач выполнено")
                        StatTile(icon: "timer", value: "\(StatsService.completedSessions(d, from: from, to: to))", label: "Сессий завершено")
                        StatTile(icon: "rectangle.on.rectangle", value: "\(cardsStudied(from: from, to: to))", label: "Карточек изучено")
                        StatTile(icon: "flame.fill", value: "\(stats.currentStreak)", label: "Текущая серия, дн.", tint: stats.currentStreak > 0 ? SB.warning : SB.silver)
                        StatTile(icon: "flame", value: "\(stats.maxStreak)", label: "Максимальная серия")
                        StatTile(icon: "bolt.fill", value: Fmt.number(StatsService.xp(d, from: from, to: to)), label: "Заработано XP")
                        StatTile(icon: "star.circle.fill", value: "\(p.level)", label: "Уровень")
                    }

                    chartCard("Минуты фокуса", empty: "Заверши сессию фокуса — и здесь появится график.",
                              data: buckets { Double(StatsService.focusMinutes(d, from: $0, to: $1)) }, tint: SB.silver)
                    chartCard("Выполненные задачи", empty: "Выполни задачу — график заполнится.",
                              data: buckets { Double(StatsService.tasksDone(d, from: $0, to: $1)) }, tint: SB.platinum)
                    activityCard
                    subjectsCard(from: from, to: to)

                    Button { showAchievements = true } label: {
                        SBCard(padding: 14, radius: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "medal.fill").foregroundStyle(SB.silver)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Достижения").font(.sb(16, .semibold)).foregroundStyle(SB.white)
                                    Text("Открыто \(d.achievements.count) из \(AchievementCatalog.all.count)").font(.sb(12)).foregroundStyle(SB.silver)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(SB.muted)
                            }
                        }
                    }.buttonStyle(.plain)

                    Button { showGoals = true } label: {
                        SBCard(padding: 14, radius: 16) {
                            HStack(spacing: 12) {
                                Image(systemName: "scope").foregroundStyle(SB.silver)
                                Text("Цели и привычки").font(.sb(16, .semibold)).foregroundStyle(SB.white)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(SB.muted)
                            }
                        }
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, SB.pad).padding(.top, 8).padding(.bottom, 28)
            }
            .background(SB.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showGoals) { GoalsHabitsView() }
            .sheet(isPresented: $showAchievements) { AchievementsView() }
        }
    }

    private func cardsStudied(from: Date, to: Date) -> Int {
        Set(store.data.reviews.filter { $0.rating != .again && $0.date >= from && $0.date < to }.map { $0.cardID }).count
    }

    private func chartCard(_ title: String, empty: String, data: [ChartBucket], tint: Color) -> some View {
        SBCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.sb(16, .semibold)).foregroundStyle(SB.white)
                if data.allSatisfy({ $0.value == 0 }) {
                    Text(empty).font(.sb(13)).foregroundStyle(SB.muted).frame(maxWidth: .infinity, minHeight: 90, alignment: .center).multilineTextAlignment(.center)
                } else {
                    Chart(data) { b in
                        BarMark(x: .value("Дата", b.date, unit: period == .all ? .weekOfYear : .day),
                                y: .value("Значение", b.value))
                            .foregroundStyle(tint)
                            .cornerRadius(3)
                    }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.defaultDigits)).foregroundStyle(SB.muted) } }
                    .chartYAxis { AxisMarks { _ in
                        AxisGridLine().foregroundStyle(SB.border)
                        AxisValueLabel().foregroundStyle(SB.muted) } }
                    .frame(height: 160)
                }
            }
        }
    }

    private var activityCard: some View {
        let d = store.data
        let today = Date().startOfDay
        let week = (0..<7).map { today.addingDays($0 - 6) }
        let data = week.map { ChartBucket(date: $0, value: Double(StatsService.activityCount(d, from: $0, to: $0.addingDays(1)))) }
        return SBCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Активность за неделю").font(.sb(16, .semibold)).foregroundStyle(SB.white)
                if data.allSatisfy({ $0.value == 0 }) {
                    Text("Задачи, сессии и повторения за последние 7 дней появятся здесь.")
                        .font(.sb(13)).foregroundStyle(SB.muted).frame(maxWidth: .infinity, minHeight: 90, alignment: .center).multilineTextAlignment(.center)
                } else {
                    Chart(data) { b in
                        LineMark(x: .value("День", b.date, unit: .day), y: .value("Действия", b.value))
                            .foregroundStyle(SB.platinum).lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(x: .value("День", b.date, unit: .day), y: .value("Действия", b.value))
                            .foregroundStyle(SB.platinum).symbolSize(36)
                    }
                    .chartXAxis { AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow)).foregroundStyle(SB.muted) } }
                    .chartYAxis { AxisMarks { _ in
                        AxisGridLine().foregroundStyle(SB.border)
                        AxisValueLabel().foregroundStyle(SB.muted) } }
                    .frame(height: 140)
                }
            }
        }
    }

    private func subjectsCard(from: Date, to: Date) -> some View {
        var minutes: [UUID: Double] = [:]
        for s in store.data.sessions where s.endedAt >= from && s.endedAt < to {
            if let id = s.subjectID, store.subject(id) != nil { minutes[id, default: 0] += s.countedMinutes }
        }
        let rows = minutes.filter { $0.value > 0 }.sorted { $0.value > $1.value }
            .map { SubjectMinutes(name: store.subjectName($0.key) ?? "—", minutes: $0.value) }
        return SBCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Время по предметам").font(.sb(16, .semibold)).foregroundStyle(SB.white)
                if rows.isEmpty {
                    Text("Привяжи задачу к предмету и запускай фокус с этой задачей — время распределится по предметам.")
                        .font(.sb(13)).foregroundStyle(SB.muted).multilineTextAlignment(.leading)
                } else {
                    Chart(rows) { r in
                        BarMark(x: .value("Минуты", r.minutes), y: .value("Предмет", r.name))
                            .foregroundStyle(SB.silver).cornerRadius(3)
                    }
                    .chartXAxis { AxisMarks { _ in
                        AxisGridLine().foregroundStyle(SB.border)
                        AxisValueLabel().foregroundStyle(SB.muted) } }
                    .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(SB.silver) } }
                    .frame(height: CGFloat(max(1, rows.count)) * 40 + 30)
                }
            }
        }
    }
}

struct AchievementsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let stats = store.stats
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(AchievementCatalog.all) { def in
                        let rec = store.data.achievements.first { $0.id == def.id }
                        let cur = min(def.current(stats), def.goal)
                        SBCard(padding: 14, radius: 16) {
                            HStack(spacing: 14) {
                                Image(systemName: def.icon).font(.system(size: 22))
                                    .foregroundStyle(rec != nil ? SB.platinum : SB.muted).frame(width: 32)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(def.title).font(.sb(16, .semibold)).foregroundStyle(rec != nil ? SB.white : SB.silver)
                                    Text(def.detail).font(.sb(12)).foregroundStyle(SB.silver)
                                    if let r = rec {
                                        Text("Получено \(Fmt.string(r.unlockedAt, "d MMMM yyyy"))").font(.sb(11)).foregroundStyle(SB.success)
                                    } else {
                                        LinearBar(value: Double(cur) / Double(def.goal), height: 4)
                                        Text("\(cur) / \(def.goal)").font(.sb(11)).monospacedDigit().foregroundStyle(SB.muted)
                                    }
                                }
                                Spacer(minLength: 0)
                                if rec != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(SB.success) }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(SB.pad)
            }
            .background(SB.background.ignoresSafeArea())
            .navigationTitle("Достижения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
    }
}
