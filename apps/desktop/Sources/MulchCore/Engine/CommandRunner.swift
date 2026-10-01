import Foundation

public struct CommandRunner: Sendable {
    public struct Result: Sendable {
        public let status: Int32
        public let output: String
        public var succeeded: Bool { status == 0 }
    }

    public enum Failure: Error, Sendable {
        case notFound(String)
    }

    public let searchPaths: [String]

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let known = [
            "/opt/homebrew/bin", "/usr/local/bin",
            home.appending(path: ".local/bin").path,
            home.appending(path: "Library/pnpm").path,
            home.appending(path: ".bun/bin").path,
            "/usr/bin", "/bin", "/usr/sbin", "/sbin",
        ]
        let inherited = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        var seen = Set<String>()
        searchPaths = (known + inherited).filter { seen.insert($0).inserted }
    }

    public func locate(_ tool: String) -> URL? {
        searchPaths
            .map { URL(filePath: $0).appending(path: tool) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    public func run(_ tool: String, _ arguments: [String], timeout: Duration = .seconds(300)) async throws -> Result {
        guard let executable = locate(tool) else { throw Failure.notFound(tool) }

        let outputURL = FileManager.default.temporaryDirectory.appending(path: "mulch-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: outputURL)
        defer {
            try? output.close()
            try? FileManager.default.removeItem(at: outputURL)
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        process.standardInput = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = searchPaths.joined(separator: ":")
        process.environment = environment

        let handle = ProcessHandle(process)
        let watchdog = Task {
            try await Task.sleep(for: timeout)
            handle.terminate()
        }
        defer { watchdog.cancel() }

        let status = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, any Error>) in
                process.terminationHandler = { continuation.resume(returning: $0.terminationStatus) }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            handle.terminate()
        }

        let data = (try? Data(contentsOf: outputURL)) ?? Data()
        return Result(status: status, output: String(decoding: data, as: UTF8.self))
    }

    public func isProcessRunning(_ pattern: String) async -> Bool {
        (try? await run("pgrep", ["-f", pattern], timeout: .seconds(10)))?.succeeded ?? false
    }
}

private final class ProcessHandle: @unchecked Sendable {
    private let process: Process
    init(_ process: Process) { self.process = process }
    func terminate() { if process.isRunning { process.terminate() } }
}
