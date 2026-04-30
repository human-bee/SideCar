import AppCore
import Foundation

public enum CodexServerRequestMethod: String, Codable, Sendable, CaseIterable {
    case commandApproval = "item/commandExecution/requestApproval"
    case fileApproval = "item/fileChange/requestApproval"
}

public enum CodexCommandApprovalDecision: String, Codable, Equatable, Sendable, CaseIterable {
    case accept
    case acceptForSession
    case decline
    case cancel
}

public enum CodexFileChangeApprovalDecision: String, Codable, Equatable, Sendable, CaseIterable {
    case accept
    case acceptForSession
    case decline
    case cancel
}

public struct CodexCommandApprovalRequest: Codable, Equatable, Sendable {
    public var itemId: String
    public var threadId: String
    public var turnId: String
    public var approvalId: String?
    public var reason: String?
    public var command: String?
    public var cwd: String?
    public var availableDecisions: [CodexCommandApprovalDecision]?
}

public struct CodexFileChangeApprovalRequest: Codable, Equatable, Sendable {
    public var itemId: String
    public var threadId: String
    public var turnId: String
    public var reason: String?
    public var grantRoot: String?
    public var availableDecisions: [CodexFileChangeApprovalDecision]?
}

public enum CodexServerRequest: Equatable, Sendable {
    case commandApproval(id: JSONRPCID, payload: CodexCommandApprovalRequest)
    case fileApproval(id: JSONRPCID, payload: CodexFileChangeApprovalRequest)
    case unknown(id: JSONRPCID, method: String, params: JSONValue?)

    public var id: JSONRPCID {
        switch self {
        case .commandApproval(let id, _), .fileApproval(let id, _), .unknown(let id, _, _):
            return id
        }
    }

    public static func decode(_ request: JSONRPCServerRequest) throws -> CodexServerRequest {
        guard let method = CodexServerRequestMethod(rawValue: request.method) else {
            return .unknown(id: request.id, method: request.method, params: request.params)
        }

        switch method {
        case .commandApproval:
            return .commandApproval(
                id: request.id,
                payload: try request.decodeParams(CodexCommandApprovalRequest.self)
            )
        case .fileApproval:
            return .fileApproval(
                id: request.id,
                payload: try request.decodeParams(CodexFileChangeApprovalRequest.self)
            )
        }
    }
}

public enum CodexApprovalResponse {
    public static func command(requestID: JSONRPCID, decision: CodexCommandApprovalDecision) -> JSONRPCResponse {
        JSONRPCResponse.result(
            id: requestID,
            payload: .object(["decision": .string(decision.rawValue)])
        )
    }

    public static func fileChange(requestID: JSONRPCID, decision: CodexFileChangeApprovalDecision) -> JSONRPCResponse {
        JSONRPCResponse.result(
            id: requestID,
            payload: .object(["decision": .string(decision.rawValue)])
        )
    }
}

public enum CodexServerRequestMapper {
    public static func timelineItem(from request: CodexServerRequest) -> TimelineItem {
        switch request {
        case .commandApproval(let id, let payload):
            return TimelineItem(
                id: payload.itemId,
                kind: .approval,
                title: "Command Approval",
                summary: payload.reason?.nilIfBlank ?? "Command approval pending.",
                detail: payload.command?.nilIfBlank,
                serverRequestID: id.stringValue,
                source: .appServerLive
            )
        case .fileApproval(let id, let payload):
            let detail = payload.grantRoot?.nilIfBlank.map { "Grant write access to \($0)" }
            return TimelineItem(
                id: payload.itemId,
                kind: .approval,
                title: "File Change Approval",
                summary: payload.reason?.nilIfBlank ?? "File change approval pending.",
                detail: detail,
                serverRequestID: id.stringValue,
                source: .appServerLive
            )
        case .unknown(let id, let method, _):
            return TimelineItem(
                id: id.stringValue,
                kind: .unknown,
                title: "Server Request",
                summary: method,
                serverRequestID: id.stringValue,
                source: .appServerLive
            )
        }
    }
}

private extension JSONRPCServerRequest {
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
}
