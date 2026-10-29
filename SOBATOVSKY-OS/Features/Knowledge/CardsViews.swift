import SwiftUI

struct CardRow: View {
    @EnvironmentObject var store: AppStore
    let card: Flashcard
    var body: some View {
        SBCard(padding: 14, radius: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.question).font(.sb(15, .semibold)).foregroundStyle(SB.white).lineLimit(2).multilineTextAlignment(.leading)
                Text(card.answer).font(.sb(13)).foregroundStyle(SB.silver).lineLimit(1)
                HStack(spacing: 8) {
                    if let s = store.subjectName(card.subjectID) { Tag(text: s) }
                    Tag(text: card.dueDate <= Date().endOfDay ? "К повторению" : "Через \(Calendar.sb.dateComponents([.day], from: Date().startOfDay, to: card.dueDate.startOfDay).day ?? 0) дн.",
                        tint: card.dueDate <= Date().endOfDay ? SB.warning : SB.muted)
                    Spacer()
                    Text("✓\(card.correctCount) ✗\(card.wrongCount)").font(.sb(11)).monospacedDigit().foregroundStyle(SB.muted)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct CardEditorView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let card: Flashcard?
    var embedded = false
    @State private var question: String
    @State private var answer: String
    @State private var subjectID: UUID?
    @State private var topicID: UUID?
    @State private var difficulty: CardDifficulty
    @State private var showError = false
    @State private var confirmDelete = false

    init(card: Flashcard?, embedded: Bool = false, presetSubject: UUID? = nil, presetTopic: UUID? = nil) {
        self.card = card
        self.embedded = embedded
        _question = State(initialValue: card?.question ?? "")
        _answer = State(initialValue: card?.answer ?? "")
        _subjectID = State(initialValue: card?.subjectID ?? presetSubject)
        _topicID = State(initialValue: card?.topicID ?? presetTopic)
        _difficulty = State(initialValue: card?.difficulty ?? .medium)
    }

    private var form: some View {
        Form {
            Section {
                TextField("Вопрос", text: $question, axis: .vertical).lineLimit(1...6)
                TextField("Ответ", text: $answer, axis: .vertical).lineLimit(1...8)
            } footer: {
                if showError { Text("Заполни вопрос и ответ.").foregroundStyle(SB.error) }
            }.listRowBackground(SB.surface)

            Section("Привязка") {
                Picker("Предмет", selection: $subjectID) {
                    Text("Нет").tag(UUID?.none)
                    ForEach(store.data.subjects) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("Тема", selection: $topicID) {
                    Text("Нет").tag(UUID?.none)
                    ForEach(store.data.topics.filter { $0.subjectID == subjectID }) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("Сложность", selection: $difficulty) { ForEach(CardDifficulty.allCases) { Text($0.title).tag($0) } }
            }.listRowBackground(SB.surface)

            if let c = card {
                Section("Статистика") {
                    LabeledContent("Верных ответов", value: "\(c.correctCount)")
                    LabeledContent("Неверных ответов", value: "\(c.wrongCount)")
                    LabeledContent("Следующее повторение", value: Fmt.dueText(c.dueDate, hasTime: false))
                    LabeledContent("Интервал", value: "\(Int(c.intervalDays)) дн.")
                }.listRowBackground(SB.surface)
                Section { Button("Удалить карточку", role: .destructive) { confirmDelete = true } }
                    .listRowBackground(SB.surface)
            }
        }
        .sbForm()
        .navigationTitle(card == nil ? "Новая карточка" : "Карточка")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: subjectID) { _, new in
            if let t = topicID, store.data.topics.first(where: { $0.id == t })?.subjectID != new { topicID = nil }
        }
        .toolbar {
            if !embedded { ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } } }
            ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.fontWeight(.semibold) }
        }
        .confirmationDialog("Удалить карточку?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) { if let c = card { store.deleteCard(c.id) }; dismiss() }
            Button("Отмена", role: .cancel) {}
        } message: { Text("Вместе с историей повторений.") }
    }

    var body: some View {
        if embedded { form } else { NavigationStack { form } }
    }

    private func save() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !a.isEmpty else { showError = true; Haptics.warning(); return }
        var c = card ?? Flashcard(question: q, answer: a)
        c.question = q; c.answer = a; c.subjectID = subjectID; c.topicID = topicID; c.difficulty = difficulty
        store.saveCard(c)
        Haptics.success()
        dismiss()
    }
}

struct CardsListView: View {
    @EnvironmentObject var store: AppStore
    let title: String
    let subjectID: UUID?
    let topicID: UUID?
    @State private var search = ""
    @State private var showNew = false

    var body: some View {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let list = store.data.cards.filter {
            (subjectID == nil || $0.subjectID == subjectID) && (topicID == nil || $0.topicID == topicID)
                && (q.isEmpty || $0.question.lowercased().contains(q) || $0.answer.lowercased().contains(q))
        }.sorted { $0.dueDate < $1.dueDate }
        ScrollView {
            VStack(spacing: 14) {
                SBSearchField(text: $search, prompt: "Поиск по карточкам")
                if list.isEmpty {
                    EmptyState(icon: "rectangle.on.rectangle", title: store.data.cards.isEmpty ? "Карточек пока нет" : "Ничего не найдено",
                               message: store.data.cards.isEmpty ? "Создай карточку и повторяй её по расписанию." : "Попробуй другой запрос.",
                               buttonTitle: store.data.cards.isEmpty ? "Новая карточка" : nil) { showNew = true }
                }
                LazyVStack(spacing: 10) {
                    ForEach(list) { c in
                        NavigationLink { CardEditorView(card: c, embedded: true) } label: { CardRow(card: c) }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, SB.pad).padding(.top, 8).padding(.bottom, 28)
        }
        .background(SB.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .primaryAction) { Button { showNew = true } label: { Image(systemName: "plus") }.accessibilityLabel("Новая карточка") } }
        .sheet(isPresented: $showNew) { CardEditorView(card: nil, presetSubject: subjectID, presetTopic: topicID) }
    }
}

struct ReviewSessionView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var queue: [UUID]
    @State private var index = 0
    @State private var revealed = false
    @State private var requeued = Set<UUID>()
    @State private var reviewed = 0
    @State private var correct = 0
    @State private var xp = 0

    init(cardIDs: [UUID]) { _queue = State(initialValue: cardIDs) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if queue.isEmpty {
                    EmptyState(icon: "checkmark.seal", title: "Всё повторено", message: "На сегодня карточек нет.")
                } else if index >= queue.count {
                    summary
                } else if let c = store.card(queue[index]) {
                    cardView(c)
                } else {
                    Color.clear.onAppear { index += 1 }
                }
            }
            .padding(SB.pad)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SB.background.ignoresSafeArea())
            .navigationTitle("Повторение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
        }
    }

    private func cardView(_ c: Flashcard) -> some View {
        VStack(spacing: 18) {
            HStack {
                Text("\(min(index + 1, queue.count)) / \(queue.count)").font(.sb(13, .medium)).monospacedDigit().foregroundStyle(SB.silver)
                LinearBar(value: Double(index) / Double(max(1, queue.count)), height: 4)
            }
            ScrollView {
                SBCard(radius: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        SBLabel("ВОПРОС")
                        Text(c.question).font(.sb(22, .semibold)).foregroundStyle(SB.white)
                        if revealed {
                            Divider().overlay(SB.border)
                            SBLabel("ОТВЕТ")
                            Text(c.answer).font(.sb(18)).foregroundStyle(SB.platinum)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if revealed {
                HStack(spacing: 8) {
                    ForEach(ReviewRating.allCases) { r in
                        Button { rate(c, r) } label: {
                            VStack(spacing: 2) {
                                Text(r.title).font(.sb(13, .semibold))
                                Text(SRSService.hint(r, for: c)).font(.sb(11)).foregroundStyle(SB.muted)
                            }
                            .foregroundStyle(r == .again ? SB.error : SB.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(SB.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SB.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .minimumScaleFactor(0.7)
                    }
                }
            } else {
                Button("Показать ответ") { Haptics.tap(); withAnimation(SBMotion.anim) { revealed = true } }.buttonStyle(.sbPrimary)
            }
        }
    }

    private func rate(_ c: Flashcard, _ r: ReviewRating) {
        Haptics.tap()
        xp += store.review(cardID: c.id, rating: r)
        reviewed += 1
        if r != .again { correct += 1 }
        if r == .again && !requeued.contains(c.id) { requeued.insert(c.id); queue.append(c.id) }
        revealed = false
        index += 1
    }

    private var summary: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal").font(.system(size: 44, weight: .light)).foregroundStyle(SB.silver)
            Text("Повторение завершено").font(.sb(24, .bold)).foregroundStyle(SB.white)
            SBCard {
                VStack(alignment: .leading, spacing: 8) {
                    row("Повторено", "\(reviewed)")
                    row("Верных ответов", "\(correct)")
                    row("Успешность", reviewed > 0 ? "\(Int((Double(correct) / Double(reviewed) * 100).rounded()))%" : "—")
                    row("Получено XP", "+\(xp)")
                }
            }
            Button("Готово") { dismiss() }.buttonStyle(.sbPrimary)
        }
    }

    private func row(_ l: String, _ v: String) -> some View {
        HStack { Text(l).foregroundStyle(SB.silver); Spacer(); Text(v).monospacedDigit().foregroundStyle(SB.white) }.font(.sb(15))
    }
}
