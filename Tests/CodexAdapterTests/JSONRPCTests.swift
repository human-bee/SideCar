import AppCore
import CodexAdapter
import Foundation
import Testing

@Test func jsonValueRoundTripsObjects() throws {
    let value = JSONValue.object([
        "threadId": .string("thread-1"),
        "includeTurns": .bool(true),
        "limit": .number(10)
    ])

    let data = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
    #expect(decoded == value)
}

@Test func jsonRPCRequestEncodesLine() throws {
    let request = JSONRPCRequest(id: 1, method: "thread/list", params: .object(["limit": .number(20)]))
    let data = try JSONRPCCodec.encodeLine(request)
    #expect(data.last == 0x0A)
    let json = String(data: data, encoding: .utf8)
    #expect(json?.contains("thread") == true)
    #expect(json?.contains("list") == true)
}

@Test func liveActionRequestBuildsTurnStart() throws {
    let action = SideCarAction(
        kind: .queueMessage,
        targetThreadId: "thread-1",
        payloadPreview: "continue with tests",
        actor: .userClick,
        source: .appServerLive,
        confirmationState: .confirmed
    )

    let request = try CodexLiveActionRequest.build(from: action)

    #expect(request.method == "turn/start")
    #expect(request.params == .object([
        "threadId": .string("thread-1"),
        "input": .array([
            .object([
                "type": .string("text"),
                "text": .string("continue with tests"),
                "text_elements": .array([])
            ])
        ])
    ]))
}

@Test func liveActionRequestBuildsTurnSteer() throws {
    let action = SideCarAction(
        kind: .steerTurn,
        targetThreadId: "thread-1",
        targetTurnId: "turn-1",
        payloadPreview: "avoid UI files",
        actor: .userClick,
        source: .appServerLive,
        confirmationState: .confirmed
    )

    let request = try CodexLiveActionRequest.build(from: action)

    #expect(request.method == "turn/steer")
    #expect(request.params == .object([
        "threadId": .string("thread-1"),
        "expectedTurnId": .string("turn-1"),
        "input": .array([
            .object([
                "type": .string("text"),
                "text": .string("avoid UI files"),
                "text_elements": .array([])
            ])
        ])
    ]))
}

@Test func liveActionRequestBuildsInterruptForkCompactAndReview() throws {
    #expect(CodexLiveActionRequest.interruptTurn(threadId: "thread-1", turnId: "turn-1") == CodexLiveActionRequest(
        method: "turn/interrupt",
        params: .object([
            "threadId": .string("thread-1"),
            "turnId": .string("turn-1")
        ])
    ))
    #expect(CodexLiveActionRequest.forkThread(threadId: "thread-1", message: "branch this") == CodexLiveActionRequest(
        method: "thread/fork",
        params: .object([
            "threadId": .string("thread-1"),
            "persistExtendedHistory": .bool(true),
            "developerInstructions": .string("branch this")
        ])
    ))
    #expect(CodexLiveActionRequest.compactThread(threadId: "thread-1", instructions: "preserve decisions") == CodexLiveActionRequest(
        method: "thread/compact/start",
        params: .object(["threadId": .string("thread-1")])
    ))
    #expect(CodexLiveActionRequest.startReview(threadId: "thread-1", instructions: "review latest diff") == CodexLiveActionRequest(
        method: "review/start",
        params: .object([
            "threadId": .string("thread-1"),
            "target": .object([
                "type": .string("custom"),
                "instructions": .string("review latest diff")
            ]),
            "delivery": .string("inline")
        ])
    ))
}

@Test func liveActionRequestKeepsApprovalDecisionBlocked() throws {
    let action = SideCarAction(
        kind: .approvalDecision,
        targetThreadId: "thread-1",
        targetTurnId: "turn-1",
        payloadPreview: "approve",
        actor: .userClick,
        source: .appServerLive,
        confirmationState: .confirmed
    )

    #expect(throws: CodexAppServerError.self) {
        _ = try CodexLiveActionRequest.build(from: action)
    }
}

@Test func processTransportBlocksExcludedCapabilitiesBeforeStartup() throws {
    let transport = CodexProcessTransport(codexPath: "/bin/echo")

    #expect(throws: CodexAppServerError.self) {
        _ = try transport.call(method: "command/exec", params: .object(["command": .string("pwd")]))
    }
    #expect(throws: CodexAppServerError.self) {
        try transport.notify(method: "fs/write", params: .object(["path": .string("file.txt")]))
    }
}

@Test func executeLiveActionUsesInitializedMockTransport() throws {
    let transport = MockCodexTransport()
    transport.results = [
        "initialize": .object(["ok": .bool(true)]),
        "turn/start": .object(["turnId": .string("turn-2")])
    ]
    let client = CodexAppServerClient(transport: transport)
    let action = SideCarAction(
        kind: .queueMessage,
        targetThreadId: "thread-1",
        payloadPreview: "ship adapter tests",
        actor: .userClick,
        source: .appServerLive,
        confirmationState: .confirmed
    )

    let result = try client.executeLiveAction(action)

    #expect(result == .object(["turnId": .string("turn-2")]))
    #expect(transport.startedModes == [.proxy])
    #expect(transport.notifications.count == 1)
    #expect(transport.notifications.first?.method == "initialized")
    #expect(transport.notifications.first?.params == nil)
    #expect(transport.calls.map(\.method) == ["initialize", "turn/start"])
    #expect(transport.calls.last?.params == .object([
        "threadId": .string("thread-1"),
        "input": .array([
            .object([
                "type": .string("text"),
                "text": .string("ship adapter tests"),
                "text_elements": .array([])
            ])
        ])
    ]))
    #expect(transport.stopCount == 1)
}

private final class MockCodexTransport: CodexAppServerTransport {
    var startedModes: [CodexAppServerLaunchMode] = []
    var stopCount = 0
    var calls: [(method: String, params: JSONValue?)] = []
    var notifications: [(method: String, params: JSONValue?)] = []
    var results: [String: JSONValue] = [:]

    func start(mode: CodexAppServerLaunchMode) throws {
        startedModes.append(mode)
    }

    func stop() {
        stopCount += 1
    }

    func call(method: String, params: JSONValue?) throws -> JSONValue? {
        calls.append((method, params))
        return results[method]
    }

    func notify(method: String, params: JSONValue?) throws {
        notifications.append((method, params))
    }
}
