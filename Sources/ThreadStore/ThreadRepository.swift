import AppCore
import Foundation

public protocol ThreadRepository {
    func activeThread() -> ThreadSnapshot
    func allThreads() -> [ThreadSnapshot]
    func search(_ query: String) -> [ThreadSnapshot]
}

public final class FixtureThreadRepository: ThreadRepository {
    private var threads: [ThreadSnapshot]
    private var activeId: String

    public init(threads: [ThreadSnapshot] = [SampleData.activeThread] + SampleData.backgroundThreads, activeId: String = SampleData.activeThread.id) {
        self.threads = threads
        self.activeId = activeId
    }

    public func activeThread() -> ThreadSnapshot {
        threads.first { $0.id == activeId } ?? SampleData.activeThread
    }

    public func allThreads() -> [ThreadSnapshot] {
        threads
    }

    public func search(_ query: String) -> [ThreadSnapshot] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return threads }
        return threads.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.summary.localizedCaseInsensitiveContains(trimmed)
                || ($0.cwd?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }
}

public struct FixtureLoader {
    public init() {}

    public func loadThreads(from url: URL) throws -> [ThreadSnapshot] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ThreadSnapshot].self, from: data)
    }

    public func saveThreads(_ threads: [ThreadSnapshot], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(threads)
        try data.write(to: url)
    }
}
