import SwiftUI

struct FocusView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var focus: FocusEngine
    @State private var confirmFinish = false
    @State private var confirmReset = false
    @State private var markedDone = false

    private var status: FocusStatus { focus.state.status }
    private var isRest: Bool { focus.state.phase == .rest }

    var body: some View {
        ZStack {
            SB.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("FOCUS MODE").font(.sb(13, .semibold)).tracking(3).foregroundStyle(SB.platinum)
                        Text("Отключись от шума. Сосредоточься на главном.")
                            .font(.sb(14)).foregroundStyle(SB.silver).multilineTextAlignment(.center)
                    }
                    FilterChips(items: FocusMode.all.map { $0.id }, selection: Binding(
                        get: { focus.state.modeID }, set: { focus.selectMode($0) })) { FocusMode.title(for: $0) }
                        .disabled(status != .idle).opacity(status == .idle ? 1 : 0.5)

                    timerRing
                    controls
                    if status == .idle { idleOptions }
                    todayCard
                }
                .padding(.horizontal, SB.pad).padding(.top, 16).padding(.bottom, 28)
            }
            if let r = focus.result { resultOverlay(r) }
        }
        .confirmationDialog("Завершить раньше времени?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Завершить и сохранить") { focus.finishEarly() }
            Button("Продолжить сессию", role: .cancel) {}
        } message: { Text("Сессия сохранится как незавершённая и не даст XP.") }
        .confirmationDialog("Сбросить таймер?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Сбросить без сохранения", role: .destructive) { focus.reset() }
            Button("Отмена", role: .cancel) {}
        } message: { Text("Прогресс этой сессии не будет сохранён.") }
    }

    private var timerRing: some View {
        let secs = focus.remainingSeconds
        return ZStack {
            ProgressRing(progress: focus.fraction, lineWidth: 8)
            VStack(spacing: 6) {
                Text(Fmt.clock(secs)).font(.system(size: 54, weight: .bold)).monospacedDigit()
                    .foregroundStyle(SB.white).minimumScaleFactor(0.6).lineLimit(1)
                Text(isRest ? "Отдых" : FocusMode.title(for: focus.state.modeID))
                    .font(.sb(14, .medium)).foregroundStyle(SB.silver)
                if status == .paused { Text("ПАУЗА").font(.sb(11, .semibold)).tracking(2).foregroundStyle(SB.warning) }
            }
            .padding(24)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Осталось \(Fmt.clock(secs))")
    }

    @ViewBuilder private var controls: some View {
        VStack(spacing: 12) {
            switch status {
            case .idle:
                Button("Старт") { focus.start() }.buttonStyle(.sbPrimary)
            case .running:
                Button("Пауза") { focus.pause() }.buttonStyle(.sbPrimary)
                secondaryRow
            case .paused:
                Button("Продолжить") { focus.resume() }.buttonStyle(.sbPrimary)
                secondaryRow
            case .finished:
                EmptyView()
            }
        }
    }

    @ViewBuilder private var secondaryRow: some View {
        if isRest {
            Button("Пропустить отдых") { focus.skipRest() }.buttonStyle(.sbSecondary)
        } else {
            HStack(spacing: 12) {
                Button("Завершить") { confirmFinish = true }.buttonStyle(.sbSecondary)
                Button("Сбросить") { confirmReset = true }.buttonStyle(.sbSecondary)
            }
        }
    }

    private var idleOptions: some View {
        let open = store.data.tasks.filter { !$0.isDone }.sorted { $0.priority.rank < $1.priority.rank }
        return VStack(spacing: 12) {
            SBCard(padding: 14, radius: 16) {
                HStack {
                    Image(systemName: "checklist").foregroundStyle(SB.silver)
                    Text("Задача").font(.sb(15)).foregroundStyle(SB.silver)
                    Spacer()
                    Menu {
                        Button("Без задачи") { focus.selectTask(nil) }
                        ForEach(open.prefix(30)) { t in Button(t.title) { focus.selectTask(t.id) } }
                    } label: {
                        Text(focus.state.taskID.flatMap { store.task($0)?.title } ?? "Не выбрана")
                            .font(.sb(15, .medium)).foregroundStyle(SB.platinum).lineLimit(1)
                    }
                }
            }
            if focus.state.modeID == "custom" {
                SBCard(padding: 14, radius: 16) {
                    VStack(spacing: 10) {
                        Stepper(value: $store.data.settings.customWorkMinutes, in: 5...180, step: 5) {
                            Text("Работа: \(store.data.settings.customWorkMinutes) мин").foregroundStyle(SB.white)
                        }
                        Stepper(value: $store.data.settings.customRestMinutes, in: 0...60, step: 5) {
                            Text("Отдых: \(store.data.settings.customRestMinutes) мин").foregroundStyle(SB.white)
                        }
                    }
                }
            }
        }
    }

    private var todayCard: some View {
        let ds = store.dayStats()
        return SBCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SBLabel("СЕГОДНЯ")
                    Text("\(ds.focusMinutes) / \(ds.focusGoal) мин").font(.sb(20, .bold)).monospacedDigit().foregroundStyle(SB.white)
                }
                Spacer()
                ProgressRing(progress: Double(ds.focusMinutes) / Double(max(1, ds.focusGoal)), lineWidth: 5).frame(width: 44, height: 44)
            }
        }
    }

    private func resultOverlay(_ r: FocusResult) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            SBCard(radius: 24) {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle").font(.system(size: 46, weight: .light)).foregroundStyle(SB.success)
                    Text("Сессия завершена").font(.sb(22, .bold)).foregroundStyle(SB.white)
                    Text("\(r.minutes) мин · +\(r.xp) XP").font(.sb(16, .medium)).monospacedDigit().foregroundStyle(SB.platinum)
                    if let id = r.taskID, let t = store.task(id), !t.isDone, !markedDone {
                        Button("Отметить «\(t.title)» выполненной") { store.toggleTask(id); markedDone = true }
                            .buttonStyle(.sbSecondary)
                    }
                    Button(r.hasRest ? "Продолжить: отдых" : "Продолжить") { markedDone = false; focus.continueAfterWork() }
                        .buttonStyle(.sbPrimary)
                    Button("Вернуться на главную") { markedDone = false; focus.dismissResult(); store.selectedTab = .overview }
                        .buttonStyle(.sbSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(SB.pad)
        }
        .transition(.opacity)
    }
}
