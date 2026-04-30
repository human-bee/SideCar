import AppCore
import Foundation

public enum VoiceTool: String, CaseIterable, Sendable {
    case getActiveThread
    case summarizeThread
    case listRunningThreads
    case draftQueueMessage
    case draftSteer
    case stageFork
    case stageInterrupt
    case stageReview
    case confirmAction
}

public struct VoiceToolPolicy: Sendable {
    public init() {}

    public func requiresConfirmation(_ tool: VoiceTool) -> Bool {
        switch tool {
        case .getActiveThread, .summarizeThread, .listRunningThreads:
            return false
        case .draftQueueMessage, .draftSteer, .stageFork, .stageInterrupt, .stageReview, .confirmAction:
            return true
        }
    }

    public func actionKind(for tool: VoiceTool) -> SideCarActionKind? {
        switch tool {
        case .draftQueueMessage:
            return .queueMessage
        case .draftSteer:
            return .steerTurn
        case .stageFork:
            return .forkThread
        case .stageInterrupt:
            return .interruptTurn
        case .stageReview:
            return .startReview
        default:
            return nil
        }
    }
}
