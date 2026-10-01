import Foundation

/// A Codable value stored in one JSON file. A missing or unreadable file yields
/// `fallback`; an unreadable one is moved aside to `<name>.broken` so it is not lost.
public struct JSONFile<Value: Codable & Sendable>: Sendable {
    public let url: URL
    public let fallback: Value

    public init(url: URL, fallback: Value) {
        self.url = url
        self.fallback = fallback
    }

    public func load() -> Value {
        guard let data = try? Data(contentsOf: url) else { return fallback }
        do {
            return try Self.decoder.decode(Value.self, from: data)
        } catch {
            let aside = url.appendingPathExtension("broken")
            try? FileManager.default.removeItem(at: aside)
            try? FileManager.default.moveItem(at: url, to: aside)
            return fallback
        }
    }

    public func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.encoder.encode(value).write(to: url, options: .atomic)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public extension JSONFile where Value == Config {
    /// `~/.config/<folder>/config.json`. Each release channel uses its own folder.
    static func config(folder: String = "mulch", home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Self {
        JSONFile(url: home.appending(path: ".config/\(folder)/config.json"), fallback: Config())
    }
}

public extension JSONFile where Value == [Run] {
    /// Keeps a year of weekly runs.
    static let historyLimit = 52

    /// `~/Library/Application Support/<folder>/history.json`.
    static func history(folder: String = "Mulch") -> Self {
        let support = URL.applicationSupportDirectory.appending(path: "\(folder)/history.json")
        return JSONFile(url: support, fallback: [])
    }
}
