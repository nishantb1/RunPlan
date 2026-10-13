import Foundation

/// Reads and writes Codable values as JSON files under one directory. Names may include a
/// subdirectory, e.g. "records/<id>.json".
public struct JSONStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public func save<T: Encodable>(_ value: T, as name: String) throws {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }

    /// nil when the file is missing. A file that fails to decode is renamed to
    /// "<name>.corrupt-<timestamp>" so the app starts clean without losing the bytes.
    public func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let value = try? JSONDecoder().decode(type, from: data) {
            return value
        }
        let stamp = Int(Date().timeIntervalSince1970)
        let aside = url.deletingLastPathComponent()
            .appendingPathComponent("\(url.lastPathComponent).corrupt-\(stamp)")
        try? FileManager.default.moveItem(at: url, to: aside)
        return nil
    }

    /// File names directly inside a subdirectory, in no particular order.
    public func names(in subdirectory: String) -> [String] {
        let url = directory.appendingPathComponent(subdirectory)
        return (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
    }

    public func delete(_ name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
}
