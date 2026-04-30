import AppCore
import Foundation

public enum CodexAppServerError: Error, CustomStringConvertible {
    case codexBinaryMissing(String)
    case transportNotStarted
    case processLaunchFailed(String)
    case rpc(JSONRPCError)
    case malformedResponse
    case unsupportedLiveAction(SideCarActionKind)
    case blockedCapability(String)

    public var description: String {
        switch self {
        case .codexBinaryMissing(let path):
            return "Codex binary missing at \(path)"
        case .transportNotStarted:
            return "App-server transport has not started."
        case .processLaunchFailed(let reason):
            return "Could not launch Codex app-server proxy: \(reason)"
        case .rpc(let error):
            return "JSON-RPC error \(error.code): \(error.message)"
        case .malformedResponse:
            return "Malformed JSON-RPC response."
        case .unsupportedLiveAction(let kind):
            return "Unsupported app-server live action: \(kind.rawValue)"
        case .blockedCapability(let method):
            return "Blocked app-server capability outside MVP scope: \(method)"
        }
    }
}

public enum CodexAppServerLaunchMode: Equatable, Sendable {
    case proxy
    case stdio
}

public protocol CodexAppServerTransport: AnyObject {
    func start(mode: CodexAppServerLaunchMode) throws
    func stop()
    func call(method: String, params: JSONValue?) throws -> JSONValue?
    func notify(method: String, params: JSONValue?) throws
}

public protocol CodexServerNotificationEventSink: AnyObject {
    func handleNotificationStreamEvent(_ event: CodexServerNotificationStreamEvent)
}

public final class CodexProcessTransport: CodexAppServerTransport {
    public static let bundledCodexPath = "/Applications/Codex.app/Contents/Resources/codex"
    public static let blockedMethods: Set<String> = ActionGate.excludedCapabilities

    private let codexPath: String
    private let notificationEventSink: CodexServerNotificationEventSink?
    private let notificationPump = CodexServerNotificationPump()
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var nextId = 1
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        codexPath: String = CodexProcessTransport.bundledCodexPath,
        notificationEventSink: CodexServerNotificationEventSink? = nil
    ) {
        self.codexPath = codexPath
        self.notificationEventSink = notificationEventSink
    }

    public func start(mode: CodexAppServerLaunchMode) throws {
        guard FileManager.default.isExecutableFile(atPath: codexPath) else {
            throw CodexAppServerError.codexBinaryMissing(codexPath)
        }

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: codexPath)
        switch mode {
        case .proxy:
            process.arguments = ["app-server", "proxy"]
        case .stdio:
            process.arguments = ["app-server", "--listen", "stdio://"]
        }
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw CodexAppServerError.processLaunchFailed(error.localizedDescription)
        }

        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
    }

    public func stop() {
        process?.terminate()
        process = nil
        inputPipe = nil
        outputPipe = nil
    }

    public func call(method: String, params: JSONValue? = nil) throws -> JSONValue? {
        try validateAllowedMethod(method)
        guard let inputPipe, let outputPipe else {
            throw CodexAppServerError.transportNotStarted
        }

        let request = JSONRPCRequest(id: nextId, method: method, params: params)
        nextId += 1
        let line = try JSONRPCCodec.encodeLine(request)
        try inputPipe.fileHandleForWriting.write(contentsOf: line)

        while true {
            let responseData = try readLine(from: outputPipe.fileHandleForReading)
            guard !responseData.isEmpty else {
                throw CodexAppServerError.malformedResponse
            }
            if let event = notificationPump.consume(line: responseData) {
                notificationEventSink?.handleNotificationStreamEvent(event)
                continue
            }
            let response = try JSONRPCCodec.decodeResponse(responseData)
            guard response.id == request.id else {
                continue
            }
            if let error = response.error {
                throw CodexAppServerError.rpc(error)
            }
            return response.result
        }
    }

    public func notify(method: String, params: JSONValue? = nil) throws {
        try validateAllowedMethod(method)
        guard let inputPipe else {
            throw CodexAppServerError.transportNotStarted
        }
        var payload: [String: JSONValue] = ["method": .string(method)]
        if let params {
            payload["params"] = params
        }
        let data = try JSONEncoder().encode(JSONValue.object(payload)) + Data([0x0A])
        try inputPipe.fileHandleForWriting.write(contentsOf: data)
    }

    private func readLine(from handle: FileHandle) throws -> Data {
        var data = Data()
        while true {
            let byte = try handle.read(upToCount: 1) ?? Data()
            if byte.isEmpty {
                break
            }
            if byte.first == 0x0A {
                break
            }
            data.append(byte)
        }
        return data
    }

    private func validateAllowedMethod(_ method: String) throws {
        if Self.blockedMethods.contains(method) {
            throw CodexAppServerError.blockedCapability(method)
        }
    }
}

public struct CodexLiveActionRequest: Equatable, Sendable {
    public let method: String
    public let params: JSONValue

    public init(method: String, params: JSONValue) {
        self.method = method
        self.params = params
    }

    public static func build(from action: SideCarAction) throws -> CodexLiveActionRequest {
        switch action.kind {
        case .queueMessage:
            return startTurn(threadId: action.targetThreadId, message: action.payloadPreview)
        case .sideQuestion:
            return sideQuestion(threadId: action.targetThreadId, question: action.payloadPreview)
        case .steerTurn:
            guard let turnId = action.targetTurnId else {
                throw CodexAppServerError.unsupportedLiveAction(action.kind)
            }
            return steerTurn(threadId: action.targetThreadId, turnId: turnId, message: action.payloadPreview)
        case .forkThread:
            return forkThread(threadId: action.targetThreadId, message: action.payloadPreview)
        case .interruptTurn:
            guard let turnId = action.targetTurnId else {
                throw CodexAppServerError.unsupportedLiveAction(action.kind)
            }
            return interruptTurn(threadId: action.targetThreadId, turnId: turnId)
        case .startReview:
            return startReview(threadId: action.targetThreadId, instructions: action.payloadPreview)
        case .compactThread:
            return compactThread(threadId: action.targetThreadId, instructions: action.payloadPreview)
        case .approvalDecision:
            throw CodexAppServerError.unsupportedLiveAction(action.kind)
        }
    }

    public static func startTurn(threadId: String, message: String) -> CodexLiveActionRequest {
        CodexLiveActionRequest(
            method: "turn/start",
            params: .object([
                "threadId": .string(threadId),
                "input": userInput(message)
            ])
        )
    }

    public static func steerTurn(threadId: String, turnId: String, message: String) -> CodexLiveActionRequest {
        CodexLiveActionRequest(
            method: "turn/steer",
            params: .object([
                "threadId": .string(threadId),
                "expectedTurnId": .string(turnId),
                "input": userInput(message)
            ])
        )
    }

    public static func interruptTurn(threadId: String, turnId: String) -> CodexLiveActionRequest {
        CodexLiveActionRequest(
            method: "turn/interrupt",
            params: .object([
                "threadId": .string(threadId),
                "turnId": .string(turnId)
            ])
        )
    }

    public static func forkThread(threadId: String, message: String? = nil) -> CodexLiveActionRequest {
        var params: [String: JSONValue] = [
            "threadId": .string(threadId),
            "persistExtendedHistory": .bool(true)
        ]
        if let message = message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            params["developerInstructions"] = .string(message)
        }
        return CodexLiveActionRequest(method: "thread/fork", params: .object(params))
    }

    public static func sideQuestion(threadId: String, question: String) -> CodexLiveActionRequest {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let instructions = """
        Side conversation requested through the SideCar /side primitive.
        Treat the parent thread history as read-only reference context.
        Answer the tangent without steering the parent turn.
        Do not mutate files, run commands, install plugins, or create worktrees unless the user explicitly asks inside this side conversation.

        User side question:
        \(trimmed)
        """

        return CodexLiveActionRequest(
            method: "thread/fork",
            params: .object([
                "threadId": .string(threadId),
                "persistExtendedHistory": .bool(false),
                "developerInstructions": .string(instructions)
            ])
        )
    }

    public static func compactThread(threadId: String, instructions: String? = nil) -> CodexLiveActionRequest {
        CodexLiveActionRequest(method: "thread/compact/start", params: .object(["threadId": .string(threadId)]))
    }

    public static func startReview(threadId: String, instructions: String? = nil) -> CodexLiveActionRequest {
        let target: JSONValue
        if let instructions = instructions?.trimmingCharacters(in: .whitespacesAndNewlines), !instructions.isEmpty {
            target = .object([
                "type": .string("custom"),
                "instructions": .string(instructions)
            ])
        } else {
            target = .object(["type": .string("uncommittedChanges")])
        }
        let params: [String: JSONValue] = [
            "threadId": .string(threadId),
            "target": target,
            "delivery": .string("inline")
        ]
        return CodexLiveActionRequest(method: "review/start", params: .object(params))
    }

    private static func userInput(_ text: String) -> JSONValue {
        .array([
            .object([
                "type": .string("text"),
                "text": .string(text),
                "text_elements": .array([])
            ])
        ])
    }
}

public struct CodexAppServerClient {
    private let transport: CodexAppServerTransport

    public init(transport: CodexAppServerTransport = CodexProcessTransport()) {
        self.transport = transport
    }

    public func probe() -> CapabilityProbe {
        do {
            try withInitializedSession {
                _ = try transport.call(method: "thread/loaded/list", params: .object(["limit": .number(1)]))
            }
            return CapabilityProbe(
                codexVersion: nil,
                appServerAvailable: true,
                codexPlusPlusAvailable: false,
                supportedMethods: [
                    "thread/list",
                    "thread/read",
                    "thread/resume",
                    "thread/fork",
                    "turn/start",
                    "turn/steer",
                    "turn/interrupt",
                    "review/start",
                    "thread/compact/start"
                ],
                transport: "stdio-proxy",
                realtimeModelAvailable: false,
                notes: ["Proxy launched. Full initialize/capability handshake is the next integration step."]
            )
        } catch {
            return CapabilityProbe(
                appServerAvailable: false,
                transport: "none",
                notes: [String(describing: error)]
            )
        }
    }

    public func loadRecentThreadSnapshots(limit: Int = 12) throws -> [ThreadSnapshot] {
        try withInitializedSession {
            let listParams: JSONValue = .object([
                "limit": .number(Double(limit)),
                "sortKey": .string("updated_at"),
                "sortDirection": .string("desc"),
                "useStateDbOnly": .bool(true)
            ])
            guard let result = try transport.call(method: "thread/list", params: listParams) else {
                return []
            }
            let response = try result.decode(CodexThreadListResponse.self)
            return response.data.map { CodexSnapshotMapper.threadSnapshot(from: $0) }
        }
    }

    public func readThreadSnapshot(threadId: String, includeTurns: Bool = true) throws -> ThreadSnapshot {
        try withInitializedSession {
            let params: JSONValue = .object([
                "threadId": .string(threadId),
                "includeTurns": .bool(includeTurns)
            ])
            guard let result = try transport.call(method: "thread/read", params: params) else {
                throw CodexAppServerError.malformedResponse
            }
            let response = try result.decode(CodexThreadReadResponse.self)
            return CodexSnapshotMapper.threadSnapshot(from: response.thread)
        }
    }

    public func loadBestAvailableSnapshots(limit: Int = 12, includeActiveTurns: Bool = true) -> [ThreadSnapshot] {
        do {
            let recent = try loadRecentThreadSnapshots(limit: limit)
            guard let first = recent.first else {
                return []
            }
            guard includeActiveTurns else {
                return recent
            }
            let active = (try? readThreadSnapshot(threadId: first.id, includeTurns: true)) ?? first
            return [active] + Array(recent.dropFirst())
        } catch {
            return [SampleData.activeThread] + SampleData.backgroundThreads
        }
    }

    public func listThreadsFixtureFallback() -> [ThreadSnapshot] {
        [SampleData.activeThread] + SampleData.backgroundThreads
    }

    @discardableResult
    public func executeLiveAction(_ action: SideCarAction) throws -> JSONValue? {
        let request = try CodexLiveActionRequest.build(from: action)
        return try withInitializedSession {
            try transport.call(method: request.method, params: request.params)
        }
    }

    private func startTransport(mode: CodexAppServerLaunchMode) throws {
        try transport.start(mode: mode)
    }

    private func withInitializedSession<T>(_ body: () throws -> T) throws -> T {
        try startInitializedTransport()
        defer { transport.stop() }
        return try body()
    }

    private func startInitializedTransport() throws {
        do {
            try startTransport(mode: .proxy)
            _ = try initialize()
        } catch {
            transport.stop()
            try startTransport(mode: .stdio)
            do {
                _ = try initialize()
            } catch {
                transport.stop()
                throw error
            }
        }
    }

    private func initialize() throws -> JSONValue? {
        let params: JSONValue = .object([
            "clientInfo": .object([
                "name": .string("SideCar"),
                "title": .string("SideCar"),
                "version": .string("0.1.0")
            ]),
            "capabilities": .object([
                "experimentalApi": .bool(true),
                "optOutNotificationMethods": .array([])
            ])
        ])
        let result = try transport.call(method: "initialize", params: params)
        try transport.notify(method: "initialized", params: nil)
        return result
    }
}
