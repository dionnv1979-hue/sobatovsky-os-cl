import SwiftUI
import UniformTypeIdentifiers

struct BackupFile: Codable {
    var format = "SOBATOVSKY-OS-BACKUP"
    var schemaVersion: Int
    var exportedAt: Date
    var appVersion: String
    var data: AppData
}

enum BackupError: LocalizedError {
    case notBackup
    case newerSchema(Int)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notBackup: return "Это не резервная копия SOBATOVSKY OS."
        case .newerSchema(let v): return "Копия создана более новой версией приложения (схема \(v)). Обнови приложение."
        case .unreadable: return "Файл повреждён или имеет неверный формат. Текущие данные не изменены."
        }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum JSONCoding {
    static func encoder(pretty: Bool = false) -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        if pretty { e.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return e
    }
    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

enum BackupService {
    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    static func export(_ data: AppData) throws -> Data {
        let file = BackupFile(schemaVersion: AppData.currentSchema, exportedAt: Date(), appVersion: appVersion, data: data)
        return try JSONCoding.encoder(pretty: true).encode(file)
    }

    /// Проверяет файл, ничего не меняя в текущих данных.
    static func parse(_ raw: Data) throws -> BackupFile {
        guard let file = try? JSONCoding.decoder().decode(BackupFile.self, from: raw) else {
            throw BackupError.unreadable
        }
        guard file.format == "SOBATOVSKY-OS-BACKUP" else { throw BackupError.notBackup }
        guard file.schemaVersion <= AppData.currentSchema else { throw BackupError.newerSchema(file.schemaVersion) }
        var f = file
        f.data = sanitize(file.data)
        return f
    }

    private static func dedupe<T: Identifiable>(_ items: [T]) -> [T] where T.ID: Hashable {
        var seen = Set<T.ID>()
        return items.filter { seen.insert($0.id).inserted }
    }

    /// Убирает дубликаты идентификаторов и дубли ключей XP.
    static func sanitize(_ d: AppData) -> AppData {
        var x = d
        x.tasks = dedupe(d.tasks)
        x.subjects = dedupe(d.subjects)
        x.topics = dedupe(d.topics)
        x.notes = dedupe(d.notes)
        x.cards = dedupe(d.cards)
        x.reviews = dedupe(d.reviews)
        x.sessions = dedupe(d.sessions)
        x.goals = dedupe(d.goals)
        x.habits = dedupe(d.habits)
        x.achievements = dedupe(d.achievements)
        var keys = Set<String>()
        x.events = dedupe(d.events).filter { keys.insert($0.key).inserted }
        x.schemaVersion = AppData.currentSchema
        return x
    }

    private static func union<T: Identifiable>(_ a: [T], _ b: [T]) -> [T] where T.ID: Hashable {
        let ids = Set(a.map { $0.id })
        return a + b.filter { !ids.contains($0.id) }
    }

    /// Объединение: добавляются только записи, которых ещё нет (по идентификатору). Настройки не трогаются.
    static func merge(current: AppData, imported: AppData) -> AppData {
        var r = current
        r.tasks = union(current.tasks, imported.tasks)
        r.subjects = union(current.subjects, imported.subjects)
        r.topics = union(current.topics, imported.topics)
        r.notes = union(current.notes, imported.notes)
        r.cards = union(current.cards, imported.cards)
        r.reviews = union(current.reviews, imported.reviews)
        r.sessions = union(current.sessions, imported.sessions)
        r.goals = union(current.goals, imported.goals)
        r.habits = union(current.habits, imported.habits)
        r.achievements = union(current.achievements, imported.achievements)
        var keys = Set(current.events.map { $0.key })
        let ids = Set(current.events.map { $0.id })
        r.events = current.events + imported.events.filter { !ids.contains($0.id) && keys.insert($0.key).inserted }
        return r
    }
}
