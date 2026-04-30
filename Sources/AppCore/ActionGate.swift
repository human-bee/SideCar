import Foundation

public enum ActionGateError: Error, Equatable, CustomStringConvertible {
    case unsupportedAction(SideCarActionKind)
    case staleSource(SnapshotSource)
    case missingTurnId(SideCarActionKind)
    case confirmationRequired
    case unsafeCapability(String)
    case wrongThread(expected: String, actual: String)

    public var description: String {
        switch self {
        case .unsupportedAction(let kind):
            return "Unsupported MVP action: \(kind.rawValue)"
        case .staleSource(let source):
            return "Cannot execute from stale source: \(source.rawValue)"
        case .missingTurnId(let kind):
            return "Action requires a target turn id: \(kind.rawValue)"
        case .confirmationRequired:
            return "Action must be explicitly confirmed before execution."
        case .unsafeCapability(let capability):
            return "Unsafe capability is outside MVP scope: \(capability)"
        case .wrongThread(let expected, let actual):
            return "Action targets \(actual), expected \(expected)."
        }
    }
}

public struct ActionGate: Sendable {
    public static let mvpSafeActions: Set<SideCarActionKind> = [
        .queueMessage,
        .steerTurn,
        .forkThread,
        .interruptTurn,
        .startReview,
        .compactThread,
        .approvalDecision
    ]

    public static let excludedCapabilities: Set<String> = [
        "thread/shellCommand",
        "command/exec",
        "fs/write",
        "config/write",
        "plugin/install",
        "worktree/create",
        "app-server/ws/non-loopback"
    ]

    public init() {}

    public func validateForStaging(_ action: SideCarAction, activeThread: ThreadSnapshot) throws {
        guard Self.mvpSafeActions.contains(action.kind) else {
            throw ActionGateError.unsupportedAction(action.kind)
        }
        guard action.targetThreadId == activeThread.id else {
            throw ActionGateError.wrongThread(expected: activeThread.id, actual: action.targetThreadId)
        }
        if activeThread.freshness.isStale {
            throw ActionGateError.staleSource(activeThread.freshness.source)
        }
        if action.kind == .steerTurn || action.kind == .interruptTurn || action.kind == .approvalDecision {
            guard action.targetTurnId != nil else {
                throw ActionGateError.missingTurnId(action.kind)
            }
        }
    }

    public func validateForExecution(_ action: SideCarAction, activeThread: ThreadSnapshot) throws {
        try validateForStaging(action, activeThread: activeThread)
        guard action.confirmationState == .confirmed else {
            throw ActionGateError.confirmationRequired
        }
    }

    public func validateCapability(_ capability: String) throws {
        if Self.excludedCapabilities.contains(capability) {
            throw ActionGateError.unsafeCapability(capability)
        }
    }
}
