import Foundation

public struct JSONFile<Value: Codable & Sendable>: Sendable {
    public let url: URL
    public let fallback: Value

    public init(url: URL, fallback: Value) {
        self.url = url
        self.fallback = fallback
    }

    public func load(onBroken: (any Error, URL) -> Void = { _, _ in }) -> Value {
        guard let data = try? Data(contentsOf: url) else { return fallback }
        do {
            return try Self.decoder.decode(Value.self, from: data)
        } catch {
            let aside = url.appendingPathExtension("broken")
            try? FileManager.default.removeItem(at: aside)
            try? FileManager.default.moveItem(at: url, to: aside)
            onBroken(error, aside)
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
    static func config(folder: String = "mulch", home: URL = FileManager.default.homeDirectoryForCurrentUser) -> Self {
        JSONFile(url: home.appending(path: ".config/\(folder)/config.json"), fallback: Config())
    }
}

public extension JSONFile where Value == [Run] {
    static let historyLimit = 52

    static func history(folder: String = "Mulch") -> Self {
        let support = URL.applicationSupportDirectory.appending(path: "\(folder)/history.json")
        return JSONFile(url: support, fallback: [])
    }
}
