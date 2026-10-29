import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var exporting = false
    @State private var exportDoc = BackupDocument(data: Data())
    @State private var importing = false
    @State private var pendingImport: BackupFile?
    @State private var errorText: String?
    @State private var confirmReset = false
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var infoText: String?

    private var exportName: String { "SOBATOVSKY-OS-backup-\(Fmt.string(Date(), "yyyy-MM-dd"))" }

    var body: some View {
        NavigationStack {
            Form {
                Section("Внешний вид") {
                    Picker("Тема", selection: $store.data.settings.theme) {
                        ForEach(ThemeChoice.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Анимации", isOn: $store.data.settings.animations)
                    Toggle("Показывать начисление XP", isOn: $store.data.settings.xpToast)
                    Toggle("Тактильная отдача", isOn: $store.data.settings.haptics)
                }.listRowBackground(SB.surface)

                Section {
                    Stepper(value: $store.data.settings.customWorkMinutes, in: 5...180, step: 5) {
                        Text("Своя сессия: работа \(store.data.settings.customWorkMinutes) мин")
                    }
                    Stepper(value: $store.data.settings.customRestMinutes, in: 0...60, step: 5) {
                        Text("Своя сессия: отдых \(store.data.settings.customRestMinutes) мин")
                    }
                    Toggle("Звук при завершении", isOn: $store.data.settings.focusSound)
                    Toggle("Уведомление об окончании", isOn: $store.data.settings.focusNotifications)
                } header: { Text("Фокус") } footer: {
                    Text("Звук играет, пока приложение открыто. В фоне сигнал подаёт системное уведомление, если оно разрешено.")
                }.listRowBackground(SB.surface)

                Section("Продуктивность") {
                    Stepper(value: $store.data.settings.dailyFocusGoalMinutes, in: 15...480, step: 15) {
                        Text("Цель по фокусу: \(Fmt.minutes(store.data.settings.dailyFocusGoalMinutes)) в день")
                    }
                    Stepper(value: $store.data.settings.dailyTaskGoal, in: 1...30) {
                        Text("Цель по задачам: \(store.data.settings.dailyTaskGoal) в день")
                    }
                    Toggle("Напоминания о задачах", isOn: $store.data.settings.taskReminders)
                    Toggle("Напоминание о карточках", isOn: $store.data.settings.cardReminderEnabled.animation(SBMotion.anim))
                    if store.data.settings.cardReminderEnabled {
                        Picker("Время напоминания", selection: $store.data.settings.cardReminderHour) {
                            ForEach(6..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                        }
                    }
                    if notifStatus == .denied {
                        Button("Уведомления выключены — открыть настройки iOS") { NotificationService.openSystemSettings() }
                            .font(.sb(13)).foregroundStyle(SB.warning)
                    }
                }.listRowBackground(SB.surface)

                Section {
                    Button { startExport() } label: { Label("Экспорт данных (JSON)", systemImage: "square.and.arrow.up") }
                    Button { importing = true } label: { Label("Импорт резервной копии", systemImage: "square.and.arrow.down") }
                    LabeledContent("Размер данных", value: byteString(LocalStorage.sizeBytes))
                    LabeledContent("Записей", value: "\(recordCount)")
                    Button("Удалить все данные", role: .destructive) { confirmReset = true }
                } header: { Text("Данные") } footer: {
                    Text("Все данные хранятся только на этом устройстве. Делай экспорт перед удалением приложения.")
                }.listRowBackground(SB.surface)

                Section("О приложении") {
                    LabeledContent("Приложение", value: "SOBATOVSKY OS")
                    LabeledContent("Версия", value: BackupService.appVersion)
                    LabeledContent("Версия схемы данных", value: "\(AppData.currentSchema)")
                    Text("Персональная система для учёбы, концентрации, знаний и целей. Работает без интернета.")
                        .font(.sb(13)).foregroundStyle(SB.silver)
                }.listRowBackground(SB.surface)
            }
            .sbForm()
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() }.fontWeight(.semibold) } }
            .onAppear { NotificationService.status { notifStatus = $0 } }
            .onChange(of: store.data.settings.taskReminders) { _, on in askPermissionIfNeeded(on) }
            .onChange(of: store.data.settings.cardReminderEnabled) { _, on in askPermissionIfNeeded(on) }
            .onChange(of: store.data.settings.focusNotifications) { _, on in askPermissionIfNeeded(on) }
            .onChange(of: store.data.settings.taskReminders) { _, _ in store.scheduleNotificationSync() }
            .onChange(of: store.data.settings.cardReminderEnabled) { _, _ in store.scheduleNotificationSync() }
            .onChange(of: store.data.settings.cardReminderHour) { _, _ in store.scheduleNotificationSync() }
            .fileExporter(isPresented: $exporting, document: exportDoc, contentType: .json, defaultFilename: exportName) { result in
                if case .failure = result { errorText = "Не удалось сохранить файл экспорта." }
                else { infoText = "Резервная копия сохранена." }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .confirmationDialog("Импорт резервной копии", isPresented: Binding(
                get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }), titleVisibility: .visible) {
                Button("Заменить все данные", role: .destructive) {
                    if let f = pendingImport { store.replaceAll(with: f.data); infoText = "Данные заменены." }
                    pendingImport = nil
                }
                Button("Объединить с текущими") {
                    if let f = pendingImport { store.merge(imported: f.data); infoText = "Данные объединены, дубликаты пропущены." }
                    pendingImport = nil
                }
                Button("Отмена", role: .cancel) { pendingImport = nil }
            } message: {
                if let f = pendingImport {
                    Text("В файле: задач — \(f.data.tasks.count), заметок — \(f.data.notes.count), карточек — \(f.data.cards.count), сессий — \(f.data.sessions.count). Копия от \(Fmt.string(f.exportedAt, "d MMMM yyyy")).")
                }
            }
            .confirmationDialog("Удалить все данные?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Удалить всё", role: .destructive) { store.resetAll(); infoText = "Все данные удалены." }
                Button("Отмена", role: .cancel) {}
            } message: { Text("Задачи, знания, статистика и достижения будут удалены без возможности восстановления. Сначала сделай экспорт, если данные нужны.") }
            .alert("Ошибка", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("Понятно", role: .cancel) {}
            } message: { Text(errorText ?? "") }
            .alert("Готово", isPresented: Binding(get: { infoText != nil }, set: { if !$0 { infoText = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(infoText ?? "") }
        }
    }

    private var recordCount: Int {
        let d = store.data
        return d.tasks.count + d.subjects.count + d.topics.count + d.notes.count + d.cards.count
            + d.sessions.count + d.goals.count + d.habits.count + d.events.count
    }

    private func byteString(_ n: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file)
    }

    private func askPermissionIfNeeded(_ on: Bool) {
        guard on else { return }
        NotificationService.requestIfNeeded { _ in NotificationService.status { notifStatus = $0 } }
    }

    private func startExport() {
        do {
            store.flush()
            exportDoc = BackupDocument(data: try BackupService.export(store.data))
            exporting = true
        } catch {
            errorText = "Не удалось подготовить резервную копию."
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { errorText = "Не удалось открыть файл."; return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let raw = try Data(contentsOf: url)
            pendingImport = try BackupService.parse(raw)
        } catch let e as BackupError {
            errorText = e.errorDescription
        } catch {
            errorText = "Не удалось прочитать файл. Текущие данные не изменены."
        }
    }
}
