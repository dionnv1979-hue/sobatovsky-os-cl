import SwiftUI

struct KnowledgeView: View {
    @EnvironmentObject var store: AppStore
    @State private var search = ""
    @State private var showSubjectEditor = false
    @State private var showNoteEditor = false
    @State private var showCardEditor = false
    @State private var showReview = false
    @State private var reviewIDs: [UUID] = []
    @State private var editingNote: Note?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    ScreenHeader("Знания", subtitle: "Всё, что ты изучаешь, в одном месте") {
                        Menu {
                            Button { showSubjectEditor = true } label: { Label("Предмет", systemImage: "book.closed") }
                            Button { showNoteEditor = true } label: { Label("Заметка", systemImage: "note.text") }
                            Button { showCardEditor = true } label: { Label("Карточка", systemImage: "rectangle.on.rectangle") }
                        } label: {
                            Image(systemName: "plus").font(.system(size: 18, weight: .medium)).foregroundStyle(SB.platinum)
                                .frame(width: 40, height: 40)
                                .background(SB.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SB.border, lineWidth: 1))
                        }
                        .accessibilityLabel("Добавить")
                    }
                    SBSearchField(text: $search, prompt: "Поиск по заметкам и карточкам")

                    if query.isEmpty { mainContent } else { searchResults }
                }
                .padding(.horizontal, SB.pad)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(SB.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSubjectEditor) { SubjectEditorView(subject: nil) }
            .sheet(isPresented: $showNoteEditor) { NoteEditorView(note: nil) }
            .sheet(item: $editingNote) { n in NoteEditorView(note: n) }
            .sheet(isPresented: $showCardEditor) { CardEditorView(card: nil) }
            .fullScreenCover(isPresented: $showReview) { ReviewSessionView(cardIDs: reviewIDs) }
        }
    }

    // MARK: Основной экран

    @ViewBuilder private var mainContent: some View {
        reviewCard
        if store.data.subjects.isEmpty {
            SBCard {
                EmptyState(icon: "books.vertical", title: "Предметов пока нет",
                           message: "Создай свой первый предмет или добавь стартовый набор.",
                           buttonTitle: "Стартовый набор") { store.createStarterSubjects() }
                Button("Создать свой предмет") { showSubjectEditor = true }
                    .buttonStyle(.sbSecondary)
            }
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(store.data.subjects) { s in
                    NavigationLink { SubjectDetailView(subjectID: s.id) } label: { SubjectCard(subject: s) }
                        .buttonStyle(.plain)
                }
            }
        }
        HStack(spacing: 12) {
            NavigationLink { NotesListView(title: "Все заметки", subjectID: nil, topicID: nil) } label: {
                libraryTile("note.text", "Заметки", "\(store.data.notes.count)")
            }.buttonStyle(.plain)
            NavigationLink { CardsListView(title: "Все карточки", subjectID: nil, topicID: nil) } label: {
                libraryTile("rectangle.on.rectangle", "Карточки", "\(store.data.cards.count)")
            }.buttonStyle(.plain)
        }
    }

    private func libraryTile(_ icon: String, _ label: String, _ value: String) -> some View {
        SBCard(padding: 14, radius: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(SB.silver)
                Text(label).font(.sb(15, .medium)).foregroundStyle(SB.white)
                Spacer()
                Text(value).font(.sb(15, .semibold)).monospacedDigit().foregroundStyle(SB.platinum)
            }
        }
    }

    private var reviewCard: some View {
        let due = store.dueCards()
        let rev = store.reviewedToday()
        let planned = due.count + rev.count
        let pct = rev.count > 0 ? Int((Double(rev.correct) / Double(rev.count) * 100).rounded()) : 0
        return SBCard(radius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                SBLabel("ПОВТОРЕНИЕ СЕГОДНЯ")
                HStack(alignment: .firstTextBaseline) {
                    Text("\(due.count)").font(.sb(38, .bold)).monospacedDigit().foregroundStyle(SB.white)
                    Text(Fmt.plural(due.count, "карточка к повторению", "карточки к повторению", "карточек к повторению"))
                        .font(.sb(14)).foregroundStyle(SB.silver)
                }
                LinearBar(value: planned > 0 ? Double(rev.count) / Double(planned) : 0)
                HStack {
                    Text("Повторено: \(rev.count) из \(planned)").font(.sb(12)).foregroundStyle(SB.silver)
                    Spacer()
                    Text("Верно: \(rev.correct) (\(pct)%)").font(.sb(12)).foregroundStyle(SB.silver)
                }
                Button(due.isEmpty ? "Нет карточек к повторению" : "Начать повторение") {
                    reviewIDs = due.map { $0.id }
                    showReview = true
                }
                .buttonStyle(.sbPrimary)
                .disabled(due.isEmpty)
                .opacity(due.isEmpty ? 0.5 : 1)
            }
        }
    }

    // MARK: Поиск

    @ViewBuilder private var searchResults: some View {
        let notes = store.data.notes.filter {
            $0.title.lowercased().contains(query) || $0.body.lowercased().contains(query)
                || $0.tags.contains { $0.lowercased().contains(query) }
        }.sorted { $0.updatedAt > $1.updatedAt }
        let cards = store.data.cards.filter {
            $0.question.lowercased().contains(query) || $0.answer.lowercased().contains(query)
        }
        let subjects = store.data.subjects.filter { $0.name.lowercased().contains(query) }
        if notes.isEmpty && cards.isEmpty && subjects.isEmpty {
            EmptyState(icon: "magnifyingglass", title: "Ничего не найдено", message: "Попробуй другой запрос.")
        }
        if !subjects.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SBLabel("ПРЕДМЕТЫ")
                ForEach(subjects) { s in
                    NavigationLink { SubjectDetailView(subjectID: s.id) } label: { SubjectCard(subject: s) }.buttonStyle(.plain)
                }
            }
        }
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SBLabel("ЗАМЕТКИ")
                ForEach(notes) { n in
                    Button { editingNote = n } label: { NoteRow(note: n) }.buttonStyle(.plain)
                }
            }
        }
        if !cards.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SBLabel("КАРТОЧКИ")
                ForEach(cards) { c in
                    NavigationLink { CardEditorView(card: c, embedded: true) } label: { CardRow(card: c) }.buttonStyle(.plain)
                }
            }
        }
    }
}

struct SubjectCard: View {
    @EnvironmentObject var store: AppStore
    let subject: Subject
    var body: some View {
        let topics = store.data.topics.filter { $0.subjectID == subject.id }.count
        let notes = store.data.notes.filter { $0.subjectID == subject.id }.count
        let cards = store.data.cards.filter { $0.subjectID == subject.id }.count
        let mastery = store.subjectMastery(subject.id)
        SBCard(padding: 14, radius: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: subject.icon).font(.system(size: 20, weight: .medium))
                    .foregroundStyle(SB.subjectColor(subject.colorIndex))
                Text(subject.name).font(.sb(16, .semibold)).foregroundStyle(SB.white)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text("\(topics) тем · \(notes) заметок")
                    .font(.sb(12)).foregroundStyle(SB.silver).lineLimit(1).minimumScaleFactor(0.8)
                Text("\(cards) карточек").font(.sb(12)).foregroundStyle(SB.silver)
                LinearBar(value: mastery, tint: SB.subjectColor(subject.colorIndex), height: 4)
                Text("Освоено \(Int((mastery * 100).rounded()))%").font(.sb(11)).foregroundStyle(SB.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct SubjectEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let subject: Subject?
    @State private var name: String
    @State private var icon: String
    @State private var colorIndex: Int

    static let icons = ["book.closed", "function", "terminal", "text.alignleft", "atom", "scope",
                        "globe", "paintpalette", "music.note", "leaf", "heart", "brain.head.profile"]

    init(subject: Subject?) {
        self.subject = subject
        _name = State(initialValue: subject?.name ?? "")
        _icon = State(initialValue: subject?.icon ?? "book.closed")
        _colorIndex = State(initialValue: subject?.colorIndex ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Название") {
                    TextField("Например, Математика", text: $name)
                }.listRowBackground(SB.surface)
                Section("Иконка") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Self.icons, id: \.self) { i in
                            Button { icon = i } label: {
                                Image(systemName: i).font(.system(size: 20))
                                    .foregroundStyle(icon == i ? SB.primaryText : SB.silver)
                                    .frame(width: 44, height: 44)
                                    .background(icon == i ? SB.primaryFill : SB.elevated,
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }.buttonStyle(.plain).accessibilityLabel("Иконка \(i)")
                        }
                    }.padding(.vertical, 4)
                }.listRowBackground(SB.surface)
                Section("Цвет") {
                    HStack(spacing: 12) {
                        ForEach(0..<SB.subjectPalette.count, id: \.self) { i in
                            Button { colorIndex = i } label: {
                                Circle().fill(SB.subjectPalette[i]).frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(SB.white, lineWidth: colorIndex == i ? 2 : 0))
                            }.buttonStyle(.plain).accessibilityLabel("Цвет \(i + 1)")
                        }
                    }.padding(.vertical, 4)
                }.listRowBackground(SB.surface)
            }
            .sbForm()
            .navigationTitle(subject == nil ? "Новый предмет" : "Предмет")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }.fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        if var s = subject {
            s.name = n; s.icon = icon; s.colorIndex = colorIndex
            store.updateSubject(s)
        } else {
            store.addSubject(name: n, icon: icon, colorIndex: colorIndex)
        }
        Haptics.success()
        dismiss()
    }
}

struct SubjectDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let subjectID: UUID
    enum Tab: String, CaseIterable, Hashable { case topics = "Темы", notes = "Заметки", cards = "Карточки" }
    @State private var tab: Tab = .topics
    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var showTopicEditor = false
    @State private var showNote = false
    @State private var showCard = false
    @State private var editingNote: Note?
    @State private var showReview = false

    var body: some View {
        if let s = store.subject(subjectID) {
            let notes = store.data.notes.filter { $0.subjectID == s.id }.sorted { $0.updatedAt > $1.updatedAt }
            let cards = store.data.cards.filter { $0.subjectID == s.id }
            let topics = store.data.topics.filter { $0.subjectID == s.id }
            ScrollView {
                VStack(spacing: 16) {
                    SBCard(radius: 22) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: s.icon).font(.system(size: 22)).foregroundStyle(SB.subjectColor(s.colorIndex))
                                Text(s.name).font(.sb(24, .bold)).foregroundStyle(SB.white)
                            }
                            LinearBar(value: store.subjectMastery(s.id), tint: SB.subjectColor(s.colorIndex))
                            Text("\(topics.count) тем · \(notes.count) заметок · \(cards.count) карточек · освоено \(Int((store.subjectMastery(s.id) * 100).rounded()))%")
                                .font(.sb(12)).foregroundStyle(SB.silver)
                            let due = store.dueCards(subjectID: s.id)
                            if !due.isEmpty {
                                Button("Повторить карточки (\(due.count))") { showReview = true }.buttonStyle(.sbSecondary)
                            }
                        }
                    }
                    FilterChips(items: Tab.allCases, selection: $tab) { $0.rawValue }
                    switch tab {
                    case .topics:
                        Button { showTopicEditor = true } label: { Label("Новая тема", systemImage: "plus") }.buttonStyle(.sbSecondary)
                        if topics.isEmpty {
                            EmptyState(icon: "list.bullet", title: "Тем пока нет", message: "Разбей предмет на темы, чтобы видеть прогресс.")
                        }
                        ForEach(topics) { t in
                            NavigationLink { TopicDetailView(topicID: t.id) } label: { TopicRow(topic: t) }.buttonStyle(.plain)
                        }
                    case .notes:
                        Button { showNote = true } label: { Label("Новая заметка", systemImage: "plus") }.buttonStyle(.sbSecondary)
                        if notes.isEmpty {
                            EmptyState(icon: "note.text", title: "Заметок пока нет", message: "Записывай важное по этому предмету.")
                        }
                        ForEach(notes) { n in
                            Button { editingNote = n } label: { NoteRow(note: n) }.buttonStyle(.plain)
                        }
                    case .cards:
                        Button { showCard = true } label: { Label("Новая карточка", systemImage: "plus") }.buttonStyle(.sbSecondary)
                        if cards.isEmpty {
                            EmptyState(icon: "rectangle.on.rectangle", title: "Карточек пока нет", message: "Создай карточки и повторяй их по расписанию.")
                        }
                        ForEach(cards) { c in
                            NavigationLink { CardEditorView(card: c, embedded: true) } label: { CardRow(card: c) }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, SB.pad).padding(.top, 8).padding(.bottom, 28)
            }
            .background(SB.background.ignoresSafeArea())
            .navigationTitle(s.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showEdit = true } label: { Label("Изменить", systemImage: "pencil") }
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Удалить", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Действия с предметом")
                }
            }
            .sheet(isPresented: $showEdit) { SubjectEditorView(subject: s) }
            .sheet(isPresented: $showTopicEditor) { TopicEditorView(subjectID: s.id, topic: nil) }
            .sheet(isPresented: $showNote) { NoteEditorView(note: nil, presetSubject: s.id) }
            .sheet(item: $editingNote) { n in NoteEditorView(note: n) }
            .sheet(isPresented: $showCard) { CardEditorView(card: nil, presetSubject: s.id) }
            .fullScreenCover(isPresented: $showReview) { ReviewSessionView(cardIDs: store.dueCards(subjectID: s.id).map { $0.id }) }
            .confirmationDialog("Удалить предмет «\(s.name)»?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить вместе с содержимым", role: .destructive) {
                    store.deleteSubject(s.id)
                    dismiss()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Будут удалены темы (\(topics.count)), заметки (\(notes.count)) и карточки (\(cards.count)). Это действие нельзя отменить.")
            }
        } else {
            EmptyState(icon: "questionmark.folder", title: "Предмет удалён", message: "Вернись назад.")
        }
    }
}

struct TopicRow: View {
    @EnvironmentObject var store: AppStore
    let topic: Topic
    var body: some View {
        let m = store.topicMastery(topic)
        SBCard(padding: 14, radius: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(topic.name).font(.sb(16, .semibold)).foregroundStyle(SB.white).multilineTextAlignment(.leading)
                    Spacer()
                    Tag(text: topic.status.title, tint: topic.status == .mastered ? SB.success : (topic.status == .needsReview ? SB.warning : SB.silver))
                }
                LinearBar(value: m, height: 4)
                Text("Освоено \(Int((m * 100).rounded()))%").font(.sb(11)).foregroundStyle(SB.muted)
            }
        }
    }
}

struct TopicEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let subjectID: UUID
    let topic: Topic?
    @State private var name: String
    @State private var details: String
    @State private var status: TopicStatus

    init(subjectID: UUID, topic: Topic?) {
        self.subjectID = subjectID
        self.topic = topic
        _name = State(initialValue: topic?.name ?? "")
        _details = State(initialValue: topic?.details ?? "")
        _status = State(initialValue: topic?.status ?? .notStarted)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("Название темы", text: $name)
                    TextField("Описание", text: $details, axis: .vertical).lineLimit(1...5)
                }.listRowBackground(SB.surface)
                Section("Статус") {
                    Picker("Статус", selection: $status) { ForEach(TopicStatus.allCases) { Text($0.title).tag($0) } }
                }.listRowBackground(SB.surface)
            }
            .sbForm()
            .navigationTitle(topic == nil ? "Новая тема" : "Тема")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !n.isEmpty else { return }
                        var t = topic ?? Topic(subjectID: subjectID, name: n)
                        t.name = n; t.details = details; t.status = status
                        store.saveTopic(t)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct TopicDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let topicID: UUID
    @State private var showEdit = false
    @State private var showNote = false
    @State private var showCard = false
    @State private var editingNote: Note?
    @State private var confirmDelete = false

    var body: some View {
        if let t = store.data.topics.first(where: { $0.id == topicID }) {
            let notes = store.data.notes.filter { $0.topicID == t.id }.sorted { $0.updatedAt > $1.updatedAt }
            let cards = store.data.cards.filter { $0.topicID == t.id }
            let m = store.topicMastery(t)
            ScrollView {
                VStack(spacing: 16) {
                    SBCard(radius: 22) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(t.name).font(.sb(24, .bold)).foregroundStyle(SB.white)
                            if !t.details.isEmpty { Text(t.details).font(.sb(14)).foregroundStyle(SB.silver) }
                            LinearBar(value: m)
                            Text("Освоено \(Int((m * 100).rounded()))%").font(.sb(12)).foregroundStyle(SB.silver)
                            Picker("Статус", selection: Binding(get: { t.status }, set: { v in
                                var x = t; x.status = v; store.saveTopic(x)
                            })) {
                                ForEach(TopicStatus.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.menu).tint(SB.platinum)
                        }
                    }
                    HStack(spacing: 12) {
                        Button { showNote = true } label: { Label("Заметка", systemImage: "plus") }.buttonStyle(.sbSecondary)
                        Button { showCard = true } label: { Label("Карточка", systemImage: "plus") }.buttonStyle(.sbSecondary)
                    }
                    if !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SBLabel("ЗАМЕТКИ")
                            ForEach(notes) { n in Button { editingNote = n } label: { NoteRow(note: n) }.buttonStyle(.plain) }
                        }
                    }
                    if !cards.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SBLabel("КАРТОЧКИ")
                            ForEach(cards) { c in NavigationLink { CardEditorView(card: c, embedded: true) } label: { CardRow(card: c) }.buttonStyle(.plain) }
                        }
                    }
                    if notes.isEmpty && cards.isEmpty {
                        EmptyState(icon: "tray", title: "Пока пусто", message: "Добавь заметки и карточки к этой теме.")
                    }
                }
                .padding(.horizontal, SB.pad).padding(.top, 8).padding(.bottom, 28)
            }
            .background(SB.background.ignoresSafeArea())
            .navigationTitle("Тема")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showEdit = true } label: { Label("Изменить", systemImage: "pencil") }
                        Button(role: .destructive) { confirmDelete = true } label: { Label("Удалить", systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Действия с темой")
                }
            }
            .sheet(isPresented: $showEdit) { TopicEditorView(subjectID: t.subjectID, topic: t) }
            .sheet(isPresented: $showNote) { NoteEditorView(note: nil, presetSubject: t.subjectID, presetTopic: t.id) }
            .sheet(item: $editingNote) { n in NoteEditorView(note: n) }
            .sheet(isPresented: $showCard) { CardEditorView(card: nil, presetSubject: t.subjectID, presetTopic: t.id) }
            .confirmationDialog("Удалить тему?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) { store.deleteTopic(t.id); dismiss() }
                Button("Отмена", role: .cancel) {}
            } message: { Text("Заметки и карточки останутся в предмете без темы.") }
        } else {
            EmptyState(icon: "questionmark.folder", title: "Тема удалена", message: "Вернись назад.")
        }
    }
}
