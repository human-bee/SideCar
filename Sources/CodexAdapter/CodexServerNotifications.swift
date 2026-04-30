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

    public init(threadId: String, status: String, activeFlags: [String]? = nil, updatedAt: TimeInterval? = nil) {
        self.threadId = threadId
        self.status = status
        self.activeFlags = activeFlags
        self.updatedAt = updatedAt
    }
}

public struct CodexTurnStartedNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var turnId: String
    public var startedAt: TimeInterval?

    public init(threadId: String, turnId: String, startedAt: TimeInterval? = nil) {
        self.threadId = threadId
        self.turnId = turnId
        self.startedAt = startedAt
    }
}

public struct CodexTurnCompletedNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var turnId: String
    public var status: String
    public var completedAt: TimeInterval?

    public init(threadId: String, turnId: String, status: String, completedAt: TimeInterval? = nil) {
        self.threadId = threadId
        self.turnId = turnId
        self.status = status
        self.completedAt = completedAt
    }
}

public struct CodexItemStartedNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var turnId: String
    public var item: CodexNotificationItem

    public init(threadId: String, turnId: String, item: CodexNotificationItem) {
        self.threadId = threadId
        self.turnId = turnId
        self.item = item
    }
}

public struct CodexItemCompletedNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var turnId: String
    public var item: CodexNotificationItem

    public init(threadId: String, turnId: String, item: CodexNotificationItem) {
        self.threadId = threadId
        self.turnId = turnId
        self.item = item
    }
}

public struct CodexCommandOutputDeltaNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var turnId: String
    public var itemId: String
    public var delta: String
    public var stream: String?
    public var sequence: Int?

    public init(threadId: String, turnId: String, itemId: String, delta: String, stream: String? = nil, sequence: Int? = nil) {
        self.threadId = threadId
        self.turnId = turnId
        self.itemId = itemId
        self.delta = delta
        self.stream = stream
        self.sequence = sequence
    }
}

public struct CodexApprovalRequestNotification: Codable, Equatable, Sendable {
    public var threadId: String
    public var turnId: String
    public var approvalId: String
    public var title: String?
    public var summary: String?
    public var kind: String?

    public init(threadId: String, turnId: String, approvalId: String, title: String? = nil, summary: String? = nil, kind: String? = nil) {
        self.threadId = threadId
        self.turnId = turnId
        self.approvalId = approvalId
        self.title = title
        self.summary = summary
        self.kind = kind
    }
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

    public init(
        id: String,
        type: String,
        text: String? = nil,
        title: String? = nil,
        summary: String? = nil,
        command: String? = nil,
        status: String? = nil,
        aggregatedOutput: String? = nil,
        metadata: JSONValue? = nil
    ) {
        self.id = id
        self.type = type
        self.text = text
        self.title = title
        self.summary = summary
        self.command = command
        self.status = status
        self.aggregatedOutput = aggregatedOutput
        self.metadata = metadata
    }
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

public enum CodexThreadSnapshotReducer {
    public static func apply(_ notification: CodexServerNotification, to snapshots: [ThreadSnapshot]) -> [ThreadSnapshot] {
        snapshots.map { snapshot in
            guard threadID(for: notification) == snapshot.id else {
                return snapshot
            }

            return apply(notification, to: snapshot)
        }
    }

    private static func apply(_ notification: CodexServerNotification, to snapshot: ThreadSnapshot) -> ThreadSnapshot {
        switch notification {
        case .threadStatusChanged(let payload):
            var snapshot = snapshot
            snapshot.status = CodexServerNotificationMapper.threadStatus(from: payload)
            snapshot.freshness = freshness(updating: snapshot.freshness, unixTimestamp: payload.updatedAt)
            if snapshot.status == .waitingForApproval {
                snapshot.currentTurn?.phase = .waitingForApproval
            }
            return snapshot

        case .turnStarted(let payload):
            var snapshot = snapshot
            let started = CodexServerNotificationMapper.turnSnapshot(started: payload)
            if snapshot.currentTurn?.id == payload.turnId {
                snapshot.currentTurn?.phase = started.phase
                snapshot.currentTurn?.startedAt = started.startedAt
                snapshot.currentTurn?.completedAt = nil
            } else {
                snapshot.currentTurn = started
            }
            snapshot.freshness = freshness(updating: snapshot.freshness, unixTimestamp: payload.startedAt)
            return snapshot

        case .turnCompleted(let payload):
            var snapshot = snapshot
            let completed = CodexServerNotificationMapper.turnSnapshot(completed: payload)
            if snapshot.currentTurn?.id == payload.turnId {
                snapshot.currentTurn?.phase = completed.phase
                snapshot.currentTurn?.completedAt = completed.completedAt
                if snapshot.currentTurn?.startedAt == nil {
                    snapshot.currentTurn?.startedAt = completed.startedAt
                }
            } else {
                snapshot.currentTurn = completed
            }
            snapshot.freshness = freshness(updating: snapshot.freshness, unixTimestamp: payload.completedAt)
            return snapshot

        case .itemStarted(let payload):
            return applyTimelineItem(
                CodexServerNotificationMapper.timelineItem(started: payload),
                to: snapshot,
                turnId: payload.turnId
            )

        case .itemCompleted(let payload):
            return applyTimelineItem(
                CodexServerNotificationMapper.timelineItem(completed: payload),
                to: snapshot,
                turnId: payload.turnId
            )

        case .commandOutputDelta(let payload):
            var snapshot = ensureCurrentTurn(on: snapshot, turnId: payload.turnId)
            let item = CodexServerNotificationMapper.timelineItem(commandOutputDelta: payload)
            appendCommandOutputDelta(item, to: &snapshot, turnId: payload.turnId)
            snapshot.freshness = freshness(updating: snapshot.freshness, unixTimestamp: nil)
            return snapshot

        case .approvalRequested(let payload):
            var snapshot = ensureCurrentTurn(on: snapshot, turnId: payload.turnId)
            let item = CodexServerNotificationMapper.timelineItem(approvalRequest: payload)
            upsert(item, into: &snapshot.currentTurn!.itemGroups)
            upsert(item, into: &snapshot.currentTurn!.blockers)
            snapshot.currentTurn?.phase = .waitingForApproval
            snapshot.status = .waitingForApproval
            snapshot.freshness = freshness(updating: snapshot.freshness, unixTimestamp: nil)
            return snapshot

        case .unknown:
            return snapshot
        }
    }

    private static func applyTimelineItem(_ item: TimelineItem, to snapshot: ThreadSnapshot, turnId: String) -> ThreadSnapshot {
        var snapshot = ensureCurrentTurn(on: snapshot, turnId: turnId)
        upsert(item, into: &snapshot.currentTurn!.itemGroups)
        snapshot.freshness = freshness(updating: snapshot.freshness, unixTimestamp: nil)
        return snapshot
    }

    private static func appendCommandOutputDelta(_ item: TimelineItem, to snapshot: inout ThreadSnapshot, turnId: String) {
        guard snapshot.currentTurn?.id == turnId else {
            return
        }

        if let index = snapshot.currentTurn?.itemGroups.firstIndex(where: { $0.id == item.id }) {
            var existing = snapshot.currentTurn!.itemGroups[index]
            existing.kind = .commandExecution
            existing.title = item.title
            existing.summary = item.summary
            existing.detail = (existing.detail ?? "") + (item.detail ?? "")
            existing.source = item.source
            snapshot.currentTurn!.itemGroups[index] = existing
        } else {
            snapshot.currentTurn?.itemGroups.append(item)
        }
    }

    private static func ensureCurrentTurn(on snapshot: ThreadSnapshot, turnId: String) -> ThreadSnapshot {
        var snapshot = snapshot
        if snapshot.currentTurn?.id != turnId {
            snapshot.currentTurn = TurnSnapshot(id: turnId, phase: .running)
        }
        return snapshot
    }

    private static func upsert(_ item: TimelineItem, into items: inout [TimelineItem]) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    private static func freshness(updating current: Freshness, unixTimestamp: TimeInterval?) -> Freshness {
        var freshness = current
        freshness.capturedAt = unixTimestamp.map(Date.init(timeIntervalSince1970:)) ?? Date()
        freshness.source = .appServerLive
        freshness.isStale = false
        return freshness
    }

    private static func threadID(for notification: CodexServerNotification) -> String? {
        switch notification {
        case .threadStatusChanged(let payload):
            return payload.threadId
        case .turnStarted(let payload):
            return payload.threadId
        case .turnCompleted(let payload):
            return payload.threadId
        case .itemStarted(let payload):
            return payload.threadId
        case .itemCompleted(let payload):
            return payload.threadId
        case .commandOutputDelta(let payload):
            return payload.threadId
        case .approvalRequested(let payload):
            return payload.threadId
        case .unknown:
            return nil
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
