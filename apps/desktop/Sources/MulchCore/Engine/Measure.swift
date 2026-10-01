import Foundation

public struct Measurement: Sendable, Equatable {
    public var bytes: Int64
    public var newest: Date?
}

public enum Measure {
    private static let keys: Set<URLResourceKey> = [
        .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
        .contentModificationDateKey, .linkCountKey,
    ]

    public static func of(_ url: URL) -> Measurement {
        let own = try? url.resourceValues(forKeys: keys)
        var result = Measurement(bytes: 0, newest: own?.contentModificationDate)
        if own?.isRegularFile == true {
            result.bytes = allocated(own)
            return result
        }
        guard let walker = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in true }
        ) else { return result }

        var seenInodes = Set<UInt64>()
        var visited = 0
        while let file = walker.nextObject() as? URL {
            visited += 1
            if visited.isMultiple(of: 4096), Task.isCancelled { break }
            guard let values = try? file.resourceValues(forKeys: keys) else { continue }
            if let date = values.contentModificationDate, date > (result.newest ?? .distantPast) {
                result.newest = date
            }
            guard values.isRegularFile == true else { continue }
            if (values.linkCount ?? 1) > 1, let inode = inode(of: file), !seenInodes.insert(inode).inserted {
                continue
            }
            result.bytes += allocated(values)
        }
        return result
    }

    public static func modificationDate(of url: URL) -> Date? {
        var fresh = url
        fresh.removeAllCachedResourceValues()
        return try? fresh.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private static func allocated(_ values: URLResourceValues?) -> Int64 {
        Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
    }

    private static func inode(of url: URL) -> UInt64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? NSNumber)?.uint64Value
    }
}

public enum DiskSpace {
    public static func available(at url: URL = FileManager.default.homeDirectoryForCurrentUser) -> Int64? {
        try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
    }
}

public enum HumanBytes {
    public static func parse(_ text: some StringProtocol) -> Int64? {
        guard let match = String(text).firstMatch(of: #/^\s*([0-9]+(?:\.[0-9]+)?)\s*([kKMGTP]?)(i?)B/#),
              let value = Double(match.1) else { return nil }
        let base: Double = match.3.isEmpty ? 1000 : 1024
        let power: Double = switch match.2.uppercased() {
        case "K": 1
        case "M": 2
        case "G": 3
        case "T": 4
        case "P": 5
        default: 0
        }
        return Int64(value * pow(base, power))
    }
}
