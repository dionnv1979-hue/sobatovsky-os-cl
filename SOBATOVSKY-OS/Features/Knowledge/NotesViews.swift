import SwiftUI

struct NoteRow: View {
    @EnvironmentObject var store: AppStore
    let note: Note
    var body: some View {
        SBCard(padding: 14, radius: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if note.isPinned { Image(systemName: "pin.fill").font(.system(size: 11)).foregroundStyle(SB.silver) }
                    Text(note.displayTitle).font(.sb(16, .semibold)).foregroundStyle(SB.white).lineLimit(1)
                    Spacer()
                    Text(Fmt.string(note.updatedAt, "d MMM")).font(.sb(11)).foregroundStyle(SB.muted)
                }
                if !note.body.isEmpty {
                    Text(note.body).font(.sb(13)).foregroundStyle(SB.silver).lineLimit(2).multilineTextAlignment(.leading)
                }
                HStack(spacing: 6) {
                    if let s = store.subjectName(note.subjectID) { Tag(text: s) }
                    ForEach(note.tags.prefix(3), id: \.self) { Tag(text: "#\($0)", tint: SB.muted) }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct NoteEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Note
    @State private var baseline: Note
    @State private var tagsText: String
    @State private var deleted = false
    @State private var confirmDelete = false
    private let isNew: Bool

    init(note: Note?, presetSubject: UUID? = nil, presetTopic: UUID? = nil) {
        var n = note ?? Note()
        if note == nil { n.subjectID = presetSubject; n.topicID = presetTopic }
        _draft = State(initialValue: n)
        _baseline = State(initialValue: note ?? Note(id: n.id, title: "", body: "", subjectID: nil, topicID: nil, tags: [], isPinned: false, createdAt: n.createdAt, updatedAt: n.updatedAt))
        _tagsText = State(initialValue: n.tags.joined(separator: ", "))
        isNew = note == nil
    }

    private func currentDraft() -> Note {
        var n = draft
        n.tags = tagsText.split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "") }
            .filter { !$0.isEmpty }
        return n
    }

    private func commit() {
        guard !deleted else { return }
        let n = currentDraft()
        if n == baseline { return }
        store.saveNote(n)
        baseline = n
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Заголовок", text: $draft.title).font(.sb(18, .semibold))
                    TextEditor(text: $draft.body)
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                        .overlay(alignment: .topLeading) {
                            if draft.body.isEmpty {
                                Text("Начни писать…").foregroundStyle(SB.muted).padding(.top, 8).padding(.leading, 5).allowsHitTesting(false)
                            }
                        }
                }.listRowBackground(SB.surface)

                Section("Привязка") {
                    Picker("Предмет", selection: $draft.subjectID) {
                        Text("Нет").tag(UUID?.none)
                        ForEach(store.data.subjects) { Text($0.name).tag(Optional($0.id)) }
                    }
                    Picker("Тема", selection: $draft.topicID) {
                        Text("Нет").tag(UUID?.none)
                        ForEach(store.data.topics.filter { $0.subjectID == draft.subjectID }) { Text($0.name).tag(Optional($0.id)) }
                    }
                    TextField("Теги через запятую", text: $tagsText)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Toggle("Закрепить", isOn: $draft.isPinned)
                }.listRowBackground(SB.surface)

                if !isNew {
                    Section {
                        Text("Создана: \(Fmt.string(draft.createdAt, "d MMMM yyyy, HH:mm"))").font(.sb(12)).foregroundStyle(SB.muted)
                        Text("Изменена: \(Fmt.string(baseline.updatedAt, "d MMMM yyyy, HH:mm"))").font(.sb(12)).foregroundStyle(SB.muted)
                        Button("Удалить заметку", role: .destructive) { confirmDelete = true }
                    }.listRowBackground(SB.surface)
                }
            }
            .sbForm()
            .navigationTitle(isNew ? "Новая заметка" : "Заметка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { commit(); dismiss() }.fontWeight(.semibold) }
            }
            .onChange(of: draft.subjectID) { _, new in
                if let t = draft.topicID, store.data.topics.first(where: { $0.id == t })?.subjectID != new { draft.topicID = nil }
            }
            .onDisappear { commit() }
            .confirmationDialog("Удалить заметку?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    deleted = true
                    store.deleteNote(draft.id)
                    dismiss()
                }
                Button("Отмена", role: .cancel) {}
            } message: { Text("Это действие нельзя отменить.") }
        }
    }
}

struct NotesListView: View {
    @EnvironmentObject var store: AppStore
    let title: String
    let subjectID: UUID?
    let topicID: UUID?
    enum Sort: String, CaseIterable, Hashable { case updated = "По изменению", created = "По созданию", name = "По названию" }
    @State private var search = ""
    @State private var sort: Sort = .updated
    @State private var tag = ""
    @State private var subjectFilter: UUID?
    @State private var editing: Note?
    @State private var showNew = false

    private var notes: [Note] {
        var list = store.data.notes.filter {
            (subjectID == nil || $0.subjectID == subjectID) && (topicID == nil || $0.topicID == topicID)
        }
        if subjectID == nil, let f = subjectFilter { list = list.filter { $0.subjectID == f } }
        if !tag.isEmpty { list = list.filter { $0.tags.contains(tag) } }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty { list = list.filter { $0.title.lowercased().contains(q) || $0.body.lowercased().contains(q) } }
        return list.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            switch sort {
            case .updated: return a.updatedAt > b.updatedAt
            case .created: return a.createdAt > b.createdAt
            case .name: return a.displayTitle.localizedCaseInsensitiveCompare(b.displayTitle) == .orderedAscending
            }
        }
    }

    private var allTags: [String] { Array(Set(store.data.notes.flatMap { $0.tags })).sorted() }

    var body: some View {
        let list = notes
        ScrollView {
            VStack(spacing: 14) {
                SBSearchField(text: $search, prompt: "Поиск по заметкам")
                HStack(spacing: 10) {
                    Menu {
                        Picker("Сортировка", selection: $sort) { ForEach(Sort.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    } label: { Label(sort.rawValue, systemImage: "arrow.up.arrow.down").font(.sb(13, .medium)) }
                    if !allTags.isEmpty {
                        Menu {
                            Picker("Тег", selection: $tag) {
                                Text("Все теги").tag("")
                                ForEach(allTags, id: \.self) { Text("#\($0)").tag($0) }
                            }
                        } label: { Label(tag.isEmpty ? "Теги" : "#\(tag)", systemImage: "tag").font(.sb(13, .medium)) }
                    }
                    if subjectID == nil && !store.data.subjects.isEmpty {
                        Menu {
                            Picker("Предмет", selection: $subjectFilter) {
                                Text("Все предметы").tag(UUID?.none)
                                ForEach(store.data.subjects) { Text($0.name).tag(Optional($0.id)) }
                            }
                        } label: { Label(store.subjectName(subjectFilter) ?? "Предмет", systemImage: "book.closed").font(.sb(13, .medium)) }
                    }
                    Spacer()
                }
                .tint(SB.platinum)
                if list.isEmpty {
                    EmptyState(icon: "note.text", title: store.data.notes.isEmpty ? "Заметок пока нет" : "Ничего не найдено",
                               message: store.data.notes.isEmpty ? "Создай первую заметку." : "Измени запрос или фильтры.",
                               buttonTitle: store.data.notes.isEmpty ? "Новая заметка" : nil) { showNew = true }
                }
                LazyVStack(spacing: 10) {
                    ForEach(list) { n in
                        Button { editing = n } label: { NoteRow(note: n) }.buttonStyle(.plain)
                            .contextMenu {
                                Button { var x = n; x.isPinned.toggle(); store.saveNote(x) } label: { Label(n.isPinned ? "Открепить" : "Закрепить", systemImage: "pin") }
                                Button(role: .destructive) { store.deleteNote(n.id) } label: { Label("Удалить", systemImage: "trash") }
                            }
                    }
                }
            }
            .padding(.horizontal, SB.pad).padding(.top, 8).padding(.bottom, 28)
        }
        .background(SB.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { showNew = true } label: { Image(systemName: "plus") }.accessibilityLabel("Новая заметка") } }
        .sheet(isPresented: $showNew) { NoteEditorView(note: nil, presetSubject: subjectID, presetTopic: topicID) }
        .sheet(item: $editing) { n in NoteEditorView(note: n) }
    }
}
