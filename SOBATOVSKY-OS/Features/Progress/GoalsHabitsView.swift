import SwiftUI

struct GoalsHabitsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    enum Tab: String, CaseIterable, Hashable { case goals = "Цели", habits = "Привычки" }
    @State private var tab: Tab = .goals
    @State private var editingGoal: Goal?
    @State private var newGoal = false
    @State private var editingHabit: Habit?
    @State private var newHabit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    FilterChips(items: Tab.allCases, selection: $tab) { $0.rawValue }
                    if tab == .goals { goalsList } else { habitsList }
                }
                .padding(SB.pad)
            }
            .background(SB.background.ignoresSafeArea())
            .navigationTitle("Цели и привычки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { if tab == .goals { newGoal = true } else { newHabit = true } } label: { Image(systemName: "plus") }
                        .accessibilityLabel(tab == .goals ? "Новая цель" : "Новая привычка")
                }
            }
            .sheet(isPresented: $newGoal) { GoalEditorView(goal: nil) }
            .sheet(item: $editingGoal) { g in GoalEditorView(goal: g) }
            .sheet(isPresented: $newHabit) { HabitEditorView(habit: nil) }
            .sheet(item: $editingHabit) { h in HabitEditorView(habit: h) }
        }
    }

    @ViewBuilder private var goalsList: some View {
        if store.data.goals.isEmpty {
            EmptyState(icon: "scope", title: "Целей пока нет",
                       message: "Например: «Провести 10 сессий фокуса» или «Повторить 100 карточек».",
                       buttonTitle: "Создать цель") { newGoal = true }
        }
        ForEach(store.data.goals.sorted { !$0.isCompleted && $1.isCompleted }) { g in
            let v = store.goalValue(g)
            let done = g.isCompleted || (g.target > 0 && v >= g.target)
            let overdue = !done && (g.deadline.map { $0 < Date().startOfDay } ?? false)
            Button { editingGoal = g } label: {
                SBCard(padding: 14, radius: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(g.title).font(.sb(16, .semibold)).foregroundStyle(SB.white).multilineTextAlignment(.leading)
                            Spacer()
                            Tag(text: done ? "Выполнена" : (overdue ? "Просрочена" : "Активна"),
                                tint: done ? SB.success : (overdue ? SB.error : SB.silver))
                        }
                        LinearBar(value: g.target > 0 ? v / g.target : 0, tint: done ? SB.success : SB.platinum)
                        HStack {
                            Text("\(Int(v.rounded())) / \(Int(g.target)) \(g.kind.unit)").font(.sb(12)).monospacedDigit().foregroundStyle(SB.silver)
                            Spacer()
                            if let dl = g.deadline { Text("до \(Fmt.string(dl, "d MMM"))").font(.sb(12)).foregroundStyle(SB.muted) }
                        }
                    }
                }
            }.buttonStyle(.plain)
        }
    }

    @ViewBuilder private var habitsList: some View {
        if store.data.habits.isEmpty {
            EmptyState(icon: "repeat", title: "Привычек пока нет",
                       message: "Привычка — это то, что ты повторяешь регулярно. Отмечай дни и копи серию.",
                       buttonTitle: "Создать привычку") { newHabit = true }
        }
        ForEach(store.data.habits) { h in
            HabitCard(habit: h) { editingHabit = h }
        }
    }
}

struct HabitCard: View {
    @EnvironmentObject var store: AppStore
    let habit: Habit
    var onEdit: () -> Void
    var body: some View {
        let today = Date().startOfDay
        let days = (0..<7).map { today.addingDays($0 - 6) }
        SBCard(padding: 14, radius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button(action: onEdit) {
                        Text(habit.title).font(.sb(16, .semibold)).foregroundStyle(SB.white).multilineTextAlignment(.leading)
                    }.buttonStyle(.plain)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").font(.system(size: 12))
                        Text("\(habit.streak())").font(.sb(13, .semibold)).monospacedDigit()
                    }.foregroundStyle(habit.streak() > 0 ? SB.warning : SB.muted)
                }
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { day in
                        let done = habit.isDone(on: day)
                        let scheduled = habit.isScheduled(day)
                        Button { Haptics.tap(); withAnimation(SBMotion.anim) { store.toggleHabit(habit.id, on: day) } } label: {
                            VStack(spacing: 4) {
                                Text(Fmt.string(day, "EEEEE")).font(.sb(10)).foregroundStyle(SB.muted)
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(done ? SB.success : (scheduled ? SB.silver : SB.border))
                            }.frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .disabled(!scheduled && !done)
                        .accessibilityLabel("\(habit.title), \(Fmt.dayTitle(day))")
                        .accessibilityValue(done ? "выполнено" : "не выполнено")
                    }
                }
                Text("Выполнение за 30 дней: \(Int((habit.completionRate() * 100).rounded()))%").font(.sb(12)).foregroundStyle(SB.silver)
            }
        }
    }
}

struct GoalEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let goal: Goal?
    @State private var title: String
    @State private var details: String
    @State private var kind: GoalKind
    @State private var target: Int
    @State private var manual: Int
    @State private var subjectID: UUID?
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var completed: Bool
    @State private var confirmDelete = false

    init(goal: Goal?) {
        self.goal = goal
        _title = State(initialValue: goal?.title ?? "")
        _details = State(initialValue: goal?.details ?? "")
        _kind = State(initialValue: goal?.kind ?? .tasksDone)
        _target = State(initialValue: Int(goal?.target ?? 10))
        _manual = State(initialValue: Int(goal?.manualValue ?? 0))
        _subjectID = State(initialValue: goal?.subjectID)
        _hasDeadline = State(initialValue: goal?.deadline != nil)
        _deadline = State(initialValue: goal?.deadline ?? Date().addingDays(7))
        _completed = State(initialValue: goal?.isCompleted ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название цели", text: $title)
                    TextField("Описание", text: $details, axis: .vertical).lineLimit(1...4)
                }.listRowBackground(SB.surface)
                Section("Измерение") {
                    Picker("Что считаем", selection: $kind) { ForEach(GoalKind.allCases) { Text($0.title).tag($0) } }
                    Stepper(value: $target, in: 1...10000, step: kind == .focusMinutes ? 15 : 1) {
                        Text("Цель: \(target) \(kind.unit)")
                    }
                    if kind == .manual {
                        Stepper(value: $manual, in: 0...10000) { Text("Сейчас: \(manual)") }
                    } else {
                        Text("Считается автоматически с даты создания цели.").font(.sb(12)).foregroundStyle(SB.muted)
                    }
                    if kind == .focusMinutes || kind == .sessions {
                        Picker("Предмет", selection: $subjectID) {
                            Text("Любой").tag(UUID?.none)
                            ForEach(store.data.subjects) { Text($0.name).tag(Optional($0.id)) }
                        }
                    }
                }.listRowBackground(SB.surface)
                Section("Срок") {
                    Toggle("Дедлайн", isOn: $hasDeadline.animation(SBMotion.anim))
                    if hasDeadline { DatePicker("До", selection: $deadline, displayedComponents: .date) }
                }.listRowBackground(SB.surface)
                if goal != nil {
                    Section {
                        Toggle("Отметить завершённой", isOn: $completed)
                        Button("Удалить цель", role: .destructive) { confirmDelete = true }
                    }.listRowBackground(SB.surface)
                }
            }
            .sbForm()
            .navigationTitle(goal == nil ? "Новая цель" : "Цель")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }.fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Удалить цель?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) { if let g = goal { store.deleteGoal(g.id) }; dismiss() }
                Button("Отмена", role: .cancel) {}
            }
        }
    }

    private func save() {
        let n = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        var g = goal ?? Goal(title: n)
        g.title = n; g.details = details; g.kind = kind; g.target = Double(target)
        g.manualValue = Double(manual); g.subjectID = (kind == .focusMinutes || kind == .sessions) ? subjectID : nil
        g.deadline = hasDeadline ? deadline : nil
        g.isCompleted = completed
        store.saveGoal(g)
        Haptics.success()
        dismiss()
    }
}

struct HabitEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let habit: Habit?
    @State private var title: String
    @State private var frequency: HabitFrequency
    @State private var reminder: Bool
    @State private var time: Date
    @State private var confirmDelete = false
    @State private var permissionDenied = false

    init(habit: Habit?) {
        self.habit = habit
        _title = State(initialValue: habit?.title ?? "")
        _frequency = State(initialValue: habit?.frequency ?? .daily)
        _reminder = State(initialValue: habit?.reminderEnabled ?? false)
        let t = Calendar.sb.date(bySettingHour: habit?.reminderHour ?? 20, minute: habit?.reminderMinute ?? 0, second: 0, of: Date()) ?? Date()
        _time = State(initialValue: t)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Название привычки", text: $title) }.listRowBackground(SB.surface)
                Section("Периодичность") {
                    Picker("Дни", selection: $frequency) { ForEach(HabitFrequency.allCases) { Text($0.title).tag($0) } }
                }.listRowBackground(SB.surface)
                Section {
                    Toggle("Напоминание", isOn: $reminder.animation(SBMotion.anim))
                    if reminder { DatePicker("Время", selection: $time, displayedComponents: .hourAndMinute) }
                } footer: {
                    if permissionDenied { Text("Уведомления выключены в настройках iOS — напоминание не сработает.") }
                }.listRowBackground(SB.surface)
                if habit != nil {
                    Section { Button("Удалить привычку", role: .destructive) { confirmDelete = true } }.listRowBackground(SB.surface)
                }
            }
            .sbForm()
            .navigationTitle(habit == nil ? "Новая привычка" : "Привычка")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: reminder) { _, on in
                guard on else { permissionDenied = false; return }
                NotificationService.requestIfNeeded { granted in permissionDenied = !granted }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }.fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .confirmationDialog("Удалить привычку?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) { if let h = habit { store.deleteHabit(h.id) }; dismiss() }
                Button("Отмена", role: .cancel) {}
            }
        }
    }

    private func save() {
        let n = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        var h = habit ?? Habit(title: n)
        h.title = n; h.frequency = frequency; h.reminderEnabled = reminder
        h.reminderHour = Calendar.sb.component(.hour, from: time)
        h.reminderMinute = Calendar.sb.component(.minute, from: time)
        store.saveHabit(h)
        Haptics.success()
        dismiss()
    }
}
