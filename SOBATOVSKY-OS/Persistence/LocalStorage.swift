import Foundation

/// Локальное хранилище: один JSON-файл в Application Support (атомарная запись).
enum LocalStorage {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SOBATOVSKY", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    static var fileURL: URL { directory.appendingPathComponent("data.json") }

    static var sizeBytes: Int {
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        return (attrs?[.size] as? Int) ?? 0
    }

    /// Загружает данные. Если файл повреждён — сохраняет его копию и начинает с чистого листа.
    static func load() -> (data: AppData, message: String?) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return (AppData(), nil) }
        do {
            let raw = try Data(contentsOf: fileURL)
            let data = try JSONCoding.decoder().decode(AppData.self, from: raw)
            return (data, nil)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let copy = directory.appendingPathComponent("data.corrupt.\(stamp).json")
            try? FileManager.default.moveItem(at: fileURL, to: copy)
            return (AppData(), "Не удалось прочитать сохранённые данные. Повреждённый файл сохранён отдельно (\(copy.lastPathComponent)), приложение запущено с чистого листа.")
        }
    }

    static func save(_ data: AppData) {
        do {
            let raw = try JSONCoding.encoder().encode(data)
            try raw.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            // Повторная попытка без защиты файла (например, устройство заблокировано).
            if let raw = try? JSONCoding.encoder().encode(data) {
                try? raw.write(to: fileURL, options: [.atomic])
            }
        }
    }
}
