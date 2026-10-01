import AppKit
import Foundation
import Observation

/// Keeps Stable on the newest release. Checks the latest GitHub release shortly after
/// launch and every six hours, and installs a newer one by itself once the app is
/// idle: the release zip replaces the bundle. Dev builds never update.
@Observable
final class Updater {
    struct Release: Equatable {
        let version: Int
        let asset: URL
    }

    enum Status: Equatable {
        case idle, checking, upToDate
        case available(Release)
        case installing
        case failed(String)
    }

    static let repository = "rafay99-epic/mulch"

    private(set) var status = Status.idle
    @ObservationIgnored private let isIdle: () -> Bool

    /// Off for Dev and for `swift run`, which has no bundle to replace.
    static var isEnabled: Bool {
        Channel.current.updates && Bundle.main.bundleURL.pathExtension == "app"
    }

    /// `isIdle` says when replacing the app would not interrupt a clean. Lives as
    /// long as the app.
    init(isIdle: @escaping () -> Bool) {
        self.isIdle = isIdle
        guard Self.isEnabled else { return }
        Task {
            try? await Task.sleep(for: .seconds(30))
            while true {
                await check(automatic: true)
                try? await Task.sleep(for: .seconds(6 * 60 * 60))
            }
        }
    }

    var available: Release? {
        if case let .available(release) = status { release } else { nil }
    }

    var statusText: String {
        switch status {
        case .idle: "Not checked yet"
        case .checking: "Checking…"
        case .upToDate: "Up to date"
        case let .available(release): "Version \(release.version) available"
        case .installing: "Installing…"
        case let .failed(message): message
        }
    }

    /// Automatic checks install right away when idle, once per version, so a broken
    /// release cannot put the app in an update loop. Manual installs always run.
    func check(automatic: Bool = false) async {
        guard Self.isEnabled, status != .checking, status != .installing else { return }
        status = .checking
        do {
            guard let release = try await Self.latest(), release.version > Int(Channel.version) ?? 0 else {
                status = .upToDate
                return
            }
            status = .available(release)
            Log.info("update: version \(release.version) available")
            let attempted = UserDefaults.standard.integer(forKey: "autoUpdateAttempt")
            if automatic, isIdle(), attempted != release.version {
                UserDefaults.standard.set(release.version, forKey: "autoUpdateAttempt")
                install()
            }
        } catch {
            Log.error("update: check failed: \(error.localizedDescription)")
            status = automatic ? .idle : .failed("Check failed: \(error.localizedDescription)")
        }
    }

    /// Hands off to a shell script that waits for the app to quit, swaps the bundle,
    /// logs the result and reopens the app.
    func install() {
        guard let release = available else { return }
        status = .installing
        do {
            let script = FileManager.default.temporaryDirectory.appending(path: "mulch-update-\(UUID().uuidString).sh")
            try Self.script.write(to: script, atomically: true, encoding: .utf8)
            let process = Process()
            process.executableURL = URL(filePath: "/bin/sh")
            process.arguments = [
                script.path, String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath,
                String(release.version), release.asset.absoluteString, Log.url.path,
            ]
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            Log.info("update: installing \(release.version)")
            NSApp.terminate(nil)
        } catch {
            Log.error("update: could not start: \(error.localizedDescription)")
            status = .failed("Update failed: \(error.localizedDescription)")
        }
    }

    /// The latest release, titled `Mulch <version>`, with its zip.
    private static func latest() async throws -> Release? {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Mulch/\(Channel.version)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 404 { return nil }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(GitHubRelease.self, from: data)
        guard let version = release.name.split(separator: " ").last.flatMap({ Int($0) }),
              let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") })?.browserDownloadUrl
        else { return nil }
        return Release(version: version, asset: asset)
    }

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: URL
        }

        let name: String
        let assets: [Asset]
    }

    /// Arguments: pid, app path, version, zip URL, log path. The download must carry the
    /// expected version and a valid signature before it replaces the app, and the old
    /// bundle is restored if the copy fails.
    private static let script = #"""
    pid="$1"; app="$2"; version="$3"; url="$4"; log="$5"
    say() { printf '%s  %s  %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" >> "$log"; }
    version_of() { /usr/bin/defaults read "$1/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null; }
    installed() { [ "$(version_of "$app")" = "$version" ]; }
    while kill -0 "$pid" 2>/dev/null; do sleep 0.5; done
    work="$(mktemp -d)"
    if /usr/bin/curl -fsSL --retry 2 "$url" -o "$work/update.zip" >> "$log" 2>&1 \
      && /usr/bin/ditto -x -k "$work/update.zip" "$work/unzipped" >> "$log" 2>&1; then
      source="$work/unzipped/$(basename "$app")"
      if [ "$(version_of "$source")" = "$version" ] && /usr/bin/codesign --verify --deep "$source" >> "$log" 2>&1; then
        rm -rf "$app.old"
        if mv "$app" "$app.old" && /usr/bin/ditto "$source" "$app" >> "$log" 2>&1; then
          rm -rf "$app.old"
        else
          rm -rf "$app"; mv "$app.old" "$app"
        fi
      else
        say ERROR "update: the download is not a valid build $version"
      fi
    fi
    rm -rf "$work"
    if installed; then say INFO "update: now on $version"; else say ERROR "update: could not install $version"; fi
    /usr/bin/open "$app"
    """#
}
