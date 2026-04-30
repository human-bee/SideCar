import Foundation

public enum SnapshotSource: String, Codable, Sendable, CaseIterable {
    case appServerLive
    case codexPlusPlusBridge
    case sqliteFallback
    case rolloutFallback
    case fixture
    case unavailable
}

public struct Freshness: Codable, Equatable, Sendable {
    public var capturedAt: Date
    public var source: SnapshotSource
    public var isStale: Bool
    public var note: String?

    public init(capturedAt: Date = Date(), source: SnapshotSource, isStale: Bool = false, note: String? = nil) {
        self.capturedAt = capturedAt
        self.source = source
        self.isStale = isStale
        self.note = note
    }
}

public enum ThreadRuntimeStatus: String, Codable, Sendable, CaseIterable {
    case idle
    case running
    case waitingForApproval
    case blocked
    case completed
    case failed
    case unknown
}

public enum TurnPhase: String, Codable, Sendable, CaseIterable {
    case queued
    case running
    case waitingForApproval
    case completed
    case failed
    case interrupted
    case unknown
}

public enum TimelineItemKind: String, Codable, Sendable, CaseIterable {
    case userMessage
    case agentMessage
    case plan
    case reasoningSummary
    case commandExecution
    case fileChange
    case mcpToolCall
    case dynamicToolCall
    case collabToolCall
    case webSearch
    case imageView
    case contextCompaction
    case approval
    case status
    case unknown
}

public struct TimelineItem: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var kind: TimelineItemKind
    public var title: String
    public var summary: String
    public var detail: String?
    public var createdAt: Date
    public var source: SnapshotSource
    public var rawPayloadPath: String?

    public init(
        id: String = UUID().uuidString,
        kind: TimelineItemKind,
        title: String,
        summary: String,
        detail: String? = nil,
        createdAt: Date = Date(),
        source: SnapshotSource,
        rawPayloadPath: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.summary = summary
        self.detail = detail
        self.createdAt = createdAt
        self.source = source
        self.rawPayloadPath = rawPayloadPath
    }
}

public struct TurnSnapshot: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var phase: TurnPhase
    public var startedAt: Date?
    public var completedAt: Date?
    public var itemGroups: [TimelineItem]
    public var blockers: [TimelineItem]

    public init(
        id: String,
        phase: TurnPhase,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        itemGroups: [TimelineItem] = [],
        blockers: [TimelineItem] = []
    ) {
        self.id = id
        self.phase = phase
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.itemGroups = itemGroups
        self.blockers = blockers
    }
}

public struct ThreadSnapshot: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var cwd: String?
    public var status: ThreadRuntimeStatus
    public var model: String?
    public var freshness: Freshness
    public var currentTurn: TurnSnapshot?
    public var summary: String
    public var recommendations: [String]

    public init(
        id: String,
        title: String,
        cwd: String? = nil,
        status: ThreadRuntimeStatus,
        model: String? = nil,
        freshness: Freshness,
        currentTurn: TurnSnapshot? = nil,
        summary: String,
        recommendations: [String] = []
    ) {
        self.id = id
        self.title = title
        self.cwd = cwd
        self.status = status
        self.model = model
        self.freshness = freshness
        self.currentTurn = currentTurn
        self.summary = summary
        self.recommendations = recommendations
    }
}

public struct PendingApprovalCenter: Equatable, Sendable {
    public struct Scope: Equatable, Sendable {
        public var threadId: String
        public var turnId: String

        public init(threadId: String, turnId: String) {
            self.threadId = threadId
            self.turnId = turnId
        }
    }

    public var scope: Scope
    public var items: [TimelineItem]

    public init?(thread: ThreadSnapshot) {
        guard
            let turn = thread.currentTurn,
            let items = Self.pendingItems(turn: turn)
        else {
            return nil
        }

        self.scope = Scope(threadId: thread.id, turnId: turn.id)
        self.items = items
    }

    public var count: Int {
        items.count
    }

    private static func pendingItems(turn: TurnSnapshot) -> [TimelineItem]? {
        let blockingItems = turn.blockers.filter { $0.kind == .approval }
        if !blockingItems.isEmpty {
            return blockingItems
        }

        let groupedItems = turn.itemGroups.filter { $0.kind == .approval }
        return groupedItems.isEmpty ? nil : groupedItems
    }
}

public enum SideCarActionKind: String, Codable, Sendable, CaseIterable {
    case queueMessage
    case steerTurn
    case forkThread
    case interruptTurn
    case startReview
    case compactThread
    case approvalDecision
}

public enum SideCarActionActor: String, Codable, Sendable, CaseIterable {
    case userClick
    case voice
    case textAgent
    case system
}

public enum ConfirmationState: String, Codable, Sendable, CaseIterable {
    case draft
    case staged
    case confirmed
    case rejected
    case executed
    case failed
}

public struct SideCarAction: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var kind: SideCarActionKind
    public var targetThreadId: String
    public var targetTurnId: String?
    public var payloadPreview: String
    public var actor: SideCarActionActor
    public var source: SnapshotSource
    public var confirmationState: ConfirmationState
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        kind: SideCarActionKind,
        targetThreadId: String,
        targetTurnId: String? = nil,
        payloadPreview: String,
        actor: SideCarActionActor,
        source: SnapshotSource,
        confirmationState: ConfirmationState = .draft,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.targetThreadId = targetThreadId
        self.targetTurnId = targetTurnId
        self.payloadPreview = payloadPreview
        self.actor = actor
        self.source = source
        self.confirmationState = confirmationState
        self.createdAt = createdAt
    }
}

public struct VisualContextBundle: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var capturedAt: Date
    public var displayName: String
    public var imagePath: String?
    public var previewAccepted: Bool
    public var sentToModel: Bool

    public init(
        id: String = UUID().uuidString,
        capturedAt: Date = Date(),
        displayName: String,
        imagePath: String? = nil,
        previewAccepted: Bool = false,
        sentToModel: Bool = false
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.displayName = displayName
        self.imagePath = imagePath
        self.previewAccepted = previewAccepted
        self.sentToModel = sentToModel
    }
}

public struct CapabilityProbe: Codable, Equatable, Sendable {
    public var codexVersion: String?
    public var appServerAvailable: Bool
    public var codexPlusPlusAvailable: Bool
    public var supportedMethods: Set<String>
    public var transport: String
    public var realtimeModelAvailable: Bool
    public var notes: [String]

    public init(
        codexVersion: String? = nil,
        appServerAvailable: Bool = false,
        codexPlusPlusAvailable: Bool = false,
        supportedMethods: Set<String> = [],
        transport: String = "none",
        realtimeModelAvailable: Bool = false,
        notes: [String] = []
    ) {
        self.codexVersion = codexVersion
        self.appServerAvailable = appServerAvailable
        self.codexPlusPlusAvailable = codexPlusPlusAvailable
        self.supportedMethods = supportedMethods
        self.transport = transport
        self.realtimeModelAvailable = realtimeModelAvailable
        self.notes = notes
    }
}
