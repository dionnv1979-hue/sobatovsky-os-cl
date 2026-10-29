import SwiftUI

enum TaskFilter: String, CaseIterable, Hashable {
    case all, today, upcoming, overdue, done
    var title: String {
        switch self {
        case .all: return "Все"
        case .today: return "Сегодня"
        case .upcoming: return "Предстоящие"
        case .overdue: return "Просроченные"
        case .done: return "Выполненные"
        }
    }
}

enum TaskSort: String, CaseIterable, Hashable {
    case date, priority, created
    var title: String {
        switch self {
        case .date: return "По сроку"
        case .priority: return "По приоритету"
        case .created: return "По созданию"
        }
    }
}

struct TasksView: View {
    @EnvironmentObject var store: AppStore
    @State private var filter: TaskFilter = .all
    @State private var sort: TaskSort = .date
    @State private var search = ""
    @State private var showNew = false
    @State private var editing: TaskItem?

    private var tasks: [TaskItem] {
        let now = Date()
        let endToday = now.endOfDay
        var list = store.data.tasks
        switch filter {
        case .all: break
        case .today: list = list.filter { $0.isDueToday }
        case .upcoming: list = list.filter { !$0.isDone && ($0.dueDate ?? .distantPast) >= endToday }
        case .overdue: list = list.filter { $0.isOverdue(now: now) }
        case .done: list = list.filter { $0.isDone }
        }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.title.lowercased().contains(q) || $0.details.lowercased().contains(q) || $0.category.lowercased().contains(q)
            }
        }
        return list.sorted { a, b in
            if a.isDone != b.isDone { return !a.isDone }
            switch sort {
            case .date:
                let da = a.dueDate ?? .distantFuture, db = b.dueDate ?? .distantFuture
                if da != db { return da < db }
                return a.priority.rank < b.priority.rank
            case .priority:
                if a.priority.rank != b.priority.rank { return a.priority.rank < b.priority.rank }
                return (a.dueDate ?? .distantFuture) < (b.dueDate ?? .distantFuture)
            case .created:
                return a.createdAt > b.createdAt
            }
        }
    }

    var body: some View {
        let list = tasks
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScreenHeader("Задачи", subtitle: "Планируй. Выполняй. Расти.") {
                        IconButton(system: "plus", label: "Новая задача") { showNew = true }
                    }
                    HStack(spacing: 10) {
                        SBSearchField(text: $search, prompt: "Поиск задач")
                        Menu {
                            Picker("Сортировка", selection: $sort) {
                                ForEach(TaskSort.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 16, weight: .medium)).foregroundStyle(SB.platinum)
                                .frame(width: 46, height: 46)
                                .background(SB.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SB.border, lineWidth: 1))
                        }
                        .accessibilityLabel("Сортировка")
                    }
                    FilterChips(items: TaskFilter.allCases, selection: $filter) { $0.title }

                    if store.data.tasks.isEmpty {
                        EmptyState(icon: "checklist", title: "Пока чистый лист",
                                   message: "Добавь первую задачу и начни двигаться к цели.",
                                   buttonTitle: "Создать задачу") { showNew = true }
                    } else if list.isEmpty {
                        EmptyState(icon: "magnifyingglass", title: "Ничего не найдено",
                                   message: search.isEmpty ? "В этой категории пока нет задач." : "Попробуй изменить запрос или фильтр.")
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(list) { t in
                                TaskRow(task: t) { editing = t }
                            }
                        }
                    }
                }
                .padding(.horizontal, SB.pad)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(SB.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showNew) { TaskEditorView(task: nil) }
            .sheet(item: $editing) { t in TaskEditorView(task: t) }
        }
    }
}

struct TaskEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private let original: TaskItem?
    @State private var title: String
    @State private var details: String
    @State private var hasDate: Bool
    @State private var hasTime: Bool
    @State private var date: Date
    @State private var priority: TaskPriority
    @State private var category: String
    @State private var subjectID: UUID?
    @State private var estimated: Int
    @State private var reminder: Bool
    @State private var repeatRule: RepeatRule
    @State private var xp: Int
    @State private var showError = false
    @State private var confirmDelete = false
    @State private var permissionDenied = false

    init(task: TaskItem?) {
        original = task
        _title = State(initialValue: task?.title ?? "")
        _details = State(initialValue: task?.details ?? "")
        _hasDate = State(initialValue: task?.dueDate != nil)
        _hasTime = State(initialValue: task?.hasTime ?? false)
        _date = State(initialValue: task?.dueDate ?? Date())
        _priority = State(initialValue: task?.priority ?? .normal)
        _category = State(initialValue: task?.category ?? "")
        _subjectID = State(initialValue: task?.subjectID)
        _estimated = State(initialValue: task?.estimatedMinutes ?? 0)
        _reminder = State(initialValue: task?.reminder ?? false)
        _repeatRule = State(initialValue: task?.repeatRule ?? .none)
        _xp = State(initialValue: task?.xp ?? TaskPriority.normal.defaultXP)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название", text: $title)
                    TextField("Описание", text: $details, axis: .vertical).lineLimit(1...5)
                } footer: {
                    if showError { Text("Укажи название задачи.").foregroundStyle(SB.error) }
                }
                .listRowBackground(SB.surface)

                Section("Срок") {
                    Toggle("Дата", isOn: $hasDate.animation(SBMotion.anim))
                    if hasDate {
                        DatePicker("Когда", selection: $date,
                                   displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date])
                        Toggle("Время", isOn: $hasTime.animation(SBMotion.anim))
                        Picker("Повторение", selection: $repeatRule) {
                            ForEach(RepeatRule.allCases) { Text($0.title).tag($0) }
                        }
                        Toggle("Напоминание", isOn: $reminder)
                    }
                } footer: {
                    if permissionDenied {
                        Text("Уведомления выключены в настройках iOS — напоминание не сработает.")
                    } else if hasDate && reminder && !hasTime {
                        Text("Без времени напоминание придёт в 09:00 выбранного дня.")
                    }
                }
                .listRowBackground(SB.surface)

                Section("Параметры") {
                    Picker("Приоритет", selection: $priority) {
                        ForEach(TaskPriority.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("Категория", selection: $category) {
                        Text("Нет").tag("")
                        ForEach(TaskCategory.presets, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Предмет", selection: $subjectID) {
                        Text("Нет").tag(UUID?.none)
                        ForEach(store.data.subjects) { s in Text(s.name).tag(Optional(s.id)) }
                    }
                    Stepper(value: $estimated, in: 0...480, step: 5) {
                        Text(estimated == 0 ? "Длительность: не задана" : "Длительность: \(Fmt.minutes(estimated))")
                    }
                    Stepper(value: $xp, in: 1...100, step: 5) {
                        Text("Награда: \(xp) XP")
                    }
                }
                .listRowBackground(SB.surface)

                if original != nil {
                    Section {
                        Button("Удалить задачу", role: .destructive) { confirmDelete = true }
                    }
                    .listRowBackground(SB.surface)
                }
            }
            .sbForm()
            .navigationTitle(original == nil ? "Новая задача" : "Задача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.fontWeight(.semibold) }
            }
            .onChange(of: priority) { _, new in
                if original == nil || xp == original?.priority.defaultXP { xp = new.defaultXP }
            }
            .onChange(of: reminder) { _, on in
                guard on else { permissionDenied = false; return }
                NotificationService.requestIfNeeded { granted in permissionDenied = !granted }
            }
            .confirmationDialog("Удалить задачу?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    if let o = original { store.deleteTask(o.id) }
                    dismiss()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Это действие нельзя отменить.")
            }
        }
    }

    private func save() {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { showError = true; Haptics.warning(); return }
        var t = original ?? TaskItem(title: name)
        t.title = name
        t.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        t.hasTime = hasDate && hasTime
        t.dueDate = hasDate ? (hasTime ? date : date.startOfDay) : nil
        t.priority = priority
        t.category = category
        t.subjectID = subjectID
        t.estimatedMinutes = estimated
        t.reminder = hasDate && reminder
        t.repeatRule = hasDate ? repeatRule : .none
        t.xp = xp
        if original == nil { store.addTask(t) } else { store.updateTask(t) }
        Haptics.success()
        dismiss()
    }
}
