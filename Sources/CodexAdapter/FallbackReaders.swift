import AppCore
import Foundation

public struct RolloutFallbackReader {
    public var sessionsRoot: URL

    public init(sessionsRoot: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/sessions")) {
        self.sessionsRoot = sessionsRoot
    }

    public func latestRolloutPaths(limit: Int = 20) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: sessionsRoot, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }

        var urls: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            urls.append(url)
        }

        return urls.sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }.prefix(limit).map { $0 }
    }
}

public struct SQLiteFallbackReader {
    public var databaseURL: URL

    public init(databaseURL: URL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/state_5.sqlite")) {
        self.databaseURL = databaseURL
    }

    public func isAvailable() -> Bool {
        FileManager.default.fileExists(atPath: databaseURL.path)
    }
}
