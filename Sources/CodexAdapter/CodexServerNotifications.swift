import AppCore
import Foundation

public enum CodexServerNotificationMethod: String, Codable, Sendable, CaseIterable {
    case threadStatusChanged = "thread/status/changed"
    case turnStarted = "turn/started"
    case turnCompleted = "turn/completed"
    case itemStarted = "item/started"
    case itemCompleted = "item/completed"
    case commandOutputDelta = "command/output/delta"
    case approvalRequested = "approval/requested"
}

public enum CodexServerNotification: Equatable, Sendable {
    case threadStatusChanged(CodexThreadStatusChangedNotification)
    case turnStarted(CodexTurnStartedNotification)
    case turnCompleted(CodexTurnCompletedNotification)
    case itemStarted(CodexItemStartedNotification)
    case itemCompleted(CodexItemCompletedNotification)
    case commandOutputDelta(CodexCommandOutputDeltaNotification)
    case approvalRequested(CodexApprovalRequestNotification)
    case unknown(method: String, params: JSONValue?)

    public static func decode(_ notification: JSONRPCNotification) throws -> CodexServerNotification {
        guard let method = CodexServerNotificationMethod(rawValue: notification.method) else {
            return .unknown(method: notification.method, params: notification.params)
        }

        switch method {
        case .threadStatusChanged:
            return .threadStatusChanged(try notification.decodeParams(CodexThreadStatusChangedNotification.self))
        case .turnStarted:
            return .turnStarted(try notification.decodeParams(CodexTurnStartedNotification.self))
        case .turnCompleted:
            return .turnCompleted(try notification.decodeParams(CodexTurnCompletedNotification.self))
        case .itemStarted:
            return .itemStarted(try notification.decodeParams(CodexItemStartedNotification.self))
        case .itemCompleted:
            return .itemCompleted(try notification.decodeParams(CodexItemCompletedNotification.self))
        case .commandOutputDelta:
            return .commandOutputDelta(try notification.decodeParams(CodexCommandOutputDeltaNotification.self))
        case .approvalRequested:
            return .approvalRequested(try notification.decodeParams(CodexApprovalRequestNotification.self))
        }
    }
}

public struct CodexThreadStatusChangedNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var status: String
    public var activeFlags: [String]?
    public var updatedAt: TimeInterval?
}

public struct CodexTurnStartedNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var turnId: String
    public var startedAt: TimeInterval?
}

public struct CodexTurnCompletedNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var turnId: String
    public var status: String
    public var completedAt: TimeInterval?
}

public struct CodexItemStartedNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var turnId: String
    public var item: CodexNotificationItem
}

public struct CodexItemCompletedNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var turnId: String
    public var item: CodexNotificationItem
}

public struct CodexCommandOutputDeltaNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var turnId: String
    public var itemId: String
    public var delta: String
    public var stream: String?
    public var sequence: Int?
}

public struct CodexApprovalRequestNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var turnId: String
    public var approvalId: String
    public var title: String?
    public var summary: String?
    public var kind: String?
}

public struct CodexNotificationItem: Codable, Equatable, Sendable {
    public var id: String
    public var type: String
    public var text: String?
    public var title: String?
    public var summary: String?
    public var command: String?
    public var status: String?
    public var aggregatedOutput: String?
    public var metadata: JSONValue?
}

public enum CodexServerNotificationMapper {
    public static func threadStatus(from notification: CodexThreadStatusChangedNotification) -> ThreadRuntimeStatus {
        if notification.status == "active", notification.activeFlags?.contains("waitingOnApproval") == true {
            return .waitingForApproval
        }
        switch notification.status {
        case "idle":
            return .idle
        case "active":
            return .running
        case "completed":
            return .completed
        case "failed", "systemError":
            return .failed
        default:
            return .unknown
        }
    }

    public static func turnSnapshot(started notification: CodexTurnStartedNotification) -> TurnSnapshot {
        TurnSnapshot(
            id: notification.turnId,
            phase: .running,
            startedAt: notification.startedAt.map(Date.init(timeIntervalSince1970:)),
            itemGroups: [],
            blockers: []
        )
    }

    public static func turnSnapshot(completed notification: CodexTurnCompletedNotification) -> TurnSnapshot {
        TurnSnapshot(
            id: notification.turnId,
            phase: turnPhase(from: notification.status),
            completedAt: notification.completedAt.map(Date.init(timeIntervalSince1970:)),
            itemGroups: [],
            blockers: []
        )
    }

    public static func timelineItem(started notification: CodexItemStartedNotification) -> TimelineItem {
        timelineItem(from: notification.item, fallbackStatus: "started")
    }

    public static func timelineItem(completed notification: CodexItemCompletedNotification) -> TimelineItem {
        timelineItem(from: notification.item, fallbackStatus: "completed")
    }

    public static func timelineItem(commandOutputDelta notification: CodexCommandOutputDeltaNotification) -> TimelineItem {
        TimelineItem(
            id: notification.itemId,
            kind: .commandExecution,
            title: notification.stream.map { "Command Output \($0)" } ?? "Command Output",
            summary: notification.delta.firstLineFallback("Command output delta"),
            detail: notification.delta,
            createdAt: Date(),
            source: .appServerLive
        )
    }

    public static func timelineItem(approvalRequest notification: CodexApprovalRequestNotification) -> TimelineItem {
        TimelineItem(
            id: notification.approvalId,
            kind: .approval,
            title: notification.title?.nilIfBlank ?? "Approval Requested",
            summary: notification.summary?.nilIfBlank ?? notification.kind?.nilIfBlank ?? "Approval request pending.",
            detail: notification.kind,
            createdAt: Date(),
            source: .appServerLive
        )
    }

    private static func timelineItem(from item: CodexNotificationItem, fallbackStatus: String) -> TimelineItem {
        TimelineItem(
            id: item.id,
            kind: itemKind(from: item.type),
            title: item.title?.nilIfBlank ?? title(for: item),
            summary: item.text?.firstLineFallback(nil)
                ?? item.summary?.firstLineFallback(nil)
                ?? item.command?.nilIfBlank
                ?? item.status?.nilIfBlank
                ?? fallbackStatus,
            detail: item.aggregatedOutput?.nilIfBlank,
            createdAt: Date(),
            source: .appServerLive
        )
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

    private static func title(for item: CodexNotificationItem) -> String {
        switch item.type {
        case "agentMessage":
            return "Agent Message"
        case "plan":
            return "Plan"
        case "reasoning":
            return "Reasoning Summary"
        case "commandExecution":
            return "Command"
        case "fileChange":
            return "File Change"
        default:
            return item.type
        }
    }

    private static func turnPhase(from status: String) -> TurnPhase {
        switch status {
        case "completed":
            return .completed
        case "interrupted":
            return .interrupted
        case "failed":
            return .failed
        case "inProgress", "running":
            return .running
        default:
            return .unknown
        }
    }
}

private extension JSONRPCNotification {
    func decodeParams<T: Decodable>(_ type: T.Type) throws -> T {
        guard let params else {
            throw CodexAppServerError.malformedResponse
        }
        return try params.decode(type)
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
