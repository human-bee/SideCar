import AppCore
import Foundation

struct CodexThreadListResponse: Decodable {
    var data: [CodexThread]
    var nextCursor: String?
}

struct CodexThreadReadResponse: Decodable {
    var thread: CodexThread
}

struct CodexThreadLoadedListResponse: Decodable {
    var data: [String]
    var nextCursor: String?
}

struct CodexThread: Decodable {
    var id: String
    var preview: String
    var modelProvider: String
    var createdAt: TimeInterval
    var updatedAt: TimeInterval
    var status: CodexThreadStatus
    var path: String?
    var cwd: String
    var cliVersion: String
    var name: String?
    var turns: [CodexTurn]
}

struct CodexThreadStatus: Decodable {
    var type: String
    var activeFlags: [String]?
}

struct CodexTurn: Decodable {
    var id: String
    var items: [CodexThreadItem]
    var status: String
    var startedAt: TimeInterval?
    var completedAt: TimeInterval?
}

struct CodexThreadItem: Decodable {
    var id: String
    var type: String
    var text: String?
    var phase: String?
    var summary: [String]?
    var content: [String]?
    var command: String?
    var cwd: String?
    var status: String?
    var aggregatedOutput: String?
    var exitCode: Int?
    var durationMs: Int?
    var server: String?
    var tool: String?
    var namespace: String?
    var query: String?
    var path: String?
    var result: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case text
        case phase
        case summary
        case content
        case command
        case cwd
        case status
        case aggregatedOutput
        case exitCode
        case durationMs
        case server
        case tool
        case namespace
        case query
        case path
        case result
    }
}

enum CodexSnapshotMapper {
    static func threadSnapshot(from thread: CodexThread, source: SnapshotSource = .appServerLive) -> ThreadSnapshot {
        let currentTurn = thread.turns.last.map { turnSnapshot(from: $0, source: source) }
        let title = thread.name?.nilIfBlank ?? thread.preview.firstLineFallback("Untitled Codex Thread")
        let summary = summaryText(for: thread, currentTurn: currentTurn)
        return ThreadSnapshot(
            id: thread.id,
            title: title,
            cwd: thread.cwd,
            status: runtimeStatus(from: thread.status, turn: currentTurn),
            model: thread.modelProvider,
            freshness: Freshness(capturedAt: Date(), source: source, isStale: thread.status.type == "notLoaded"),
            currentTurn: currentTurn,
            summary: summary,
            recommendations: recommendations(for: thread, currentTurn: currentTurn)
        )
    }

    static func turnSnapshot(from turn: CodexTurn, source: SnapshotSource) -> TurnSnapshot {
        let items = turn.items.map { timelineItem(from: $0, source: source) }
        let blockers = items.filter { $0.kind == .approval || $0.summary.localizedCaseInsensitiveContains("approval") }
        return TurnSnapshot(
            id: turn.id,
            phase: turnPhase(from: turn.status, blockers: blockers),
            startedAt: turn.startedAt.map(Date.init(timeIntervalSince1970:)),
            completedAt: turn.completedAt.map(Date.init(timeIntervalSince1970:)),
            itemGroups: items,
            blockers: blockers
        )
    }

    static func timelineItem(from item: CodexThreadItem, source: SnapshotSource) -> TimelineItem {
        TimelineItem(
            id: item.id,
            kind: itemKind(from: item.type),
            title: title(for: item),
            summary: summary(for: item),
            detail: detail(for: item),
            createdAt: Date(),
            source: source
        )
    }

    private static func runtimeStatus(from status: CodexThreadStatus, turn: TurnSnapshot?) -> ThreadRuntimeStatus {
        if status.type == "active", status.activeFlags?.contains("waitingOnApproval") == true {
            return .waitingForApproval
        }
        switch status.type {
        case "idle":
            return .idle
        case "active":
            return .running
        case "systemError":
            return .failed
        case "notLoaded":
            return turn?.phase == .completed ? .completed : .unknown
        default:
            return .unknown
        }
    }

    private static func turnPhase(from status: String, blockers: [TimelineItem]) -> TurnPhase {
        if !blockers.isEmpty {
            return .waitingForApproval
        }
        switch status {
        case "completed":
            return .completed
        case "interrupted":
            return .interrupted
        case "failed":
            return .failed
        case "inProgress":
            return .running
        default:
            return .unknown
        }
    }

    private static func itemKind(from type: String) -> TimelineItemKind {
        switch type {
        case "userMessage":
            return .userMessage
        case "agentMessage":
            return .agentMessage
        case "plan":
            return .plan
        case "reasoning":
            return .reasoningSummary
        case "commandExecution":
            return .commandExecution
        case "fileChange":
            return .fileChange
        case "mcpToolCall":
            return .mcpToolCall
        case "dynamicToolCall":
            return .dynamicToolCall
        case "collabAgentToolCall":
            return .collabToolCall
        case "webSearch":
            return .webSearch
        case "imageView", "imageGeneration":
            return .imageView
        case "contextCompaction":
            return .contextCompaction
        default:
            return .unknown
        }
    }

    private static func title(for item: CodexThreadItem) -> String {
        switch item.type {
        case "agentMessage":
            return item.phase == "final_answer" ? "Final Answer" : "Agent Message"
        case "plan":
            return "Plan"
        case "reasoning":
            return "Reasoning Summary"
        case "commandExecution":
            return "Command"
        case "fileChange":
            return "File Change"
        case "mcpToolCall":
            return [item.server, item.tool].compactMap { $0 }.joined(separator: " / ").nilIfBlank ?? "MCP Tool"
        case "dynamicToolCall":
            return [item.namespace, item.tool].compactMap { $0 }.joined(separator: " / ").nilIfBlank ?? "Tool Call"
        case "webSearch":
            return "Web Search"
        case "imageGeneration":
            return "Image Generation"
        case "imageView":
            return "Image View"
        default:
            return item.type
        }
    }

    private static func summary(for item: CodexThreadItem) -> String {
        if let text = item.text?.firstLineFallback(nil) {
            return text
        }
        if let summary = item.summary, !summary.isEmpty {
            return summary.joined(separator: " ").firstLineFallback("Reasoning summary")
        }
        if let command = item.command {
            return command
        }
        if let query = item.query {
            return query
        }
        if let path = item.path {
            return path
        }
        if let result = item.result?.firstLineFallback(nil) {
            return result
        }
        if let status = item.status {
            return status
        }
        return item.type
    }

    private static func detail(for item: CodexThreadItem) -> String? {
        if let output = item.aggregatedOutput?.nilIfBlank {
            return output
        }
        if let content = item.content, !content.isEmpty {
            return content.joined(separator: "\n")
        }
        if let cwd = item.cwd, let status = item.status {
            return "\(status) in \(cwd)"
        }
        return item.status
    }

    private static func summaryText(for thread: CodexThread, currentTurn: TurnSnapshot?) -> String {
        if let final = currentTurn?.itemGroups.last(where: { $0.title == "Final Answer" }) {
            return final.summary
        }
        if let latest = currentTurn?.itemGroups.last {
            return "Latest activity: \(latest.title) - \(latest.summary)"
        }
        return thread.preview.firstLineFallback("No thread summary available.")
    }

    private static func recommendations(for thread: CodexThread, currentTurn: TurnSnapshot?) -> [String] {
        if currentTurn?.phase == .waitingForApproval {
            return ["Review the pending approval before the Codex turn stalls."]
        }
        if thread.status.type == "notLoaded" {
            return ["Resume or read the thread before attempting live steering."]
        }
        return ["Inspect the latest timeline items before staging any mutation."]
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func firstLineFallback(_ fallback: String?) -> String {
        split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfBlank ?? fallback ?? self
    }
}
