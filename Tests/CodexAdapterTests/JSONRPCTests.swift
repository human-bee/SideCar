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

@Test func serverNotificationDecodesThreadStatusChanged() throws {
    let notification = try decodeNotification("""
    {
      "jsonrpc": "2.0",
      "method": "thread/status/changed",
      "params": {
        "threadId": "thread-1",
        "status": "active",
        "activeFlags": ["waitingOnApproval"],
        "updatedAt": 1777588800
      }
    }
    """)

    let event = try CodexServerNotification.decode(notification)

    guard case .threadStatusChanged(let payload) = event else {
        Issue.record("Expected thread/status/changed event")
        return
    }
    #expect(payload.threadId == "thread-1")
    #expect(CodexServerNotificationMapper.threadStatus(from: payload) == .waitingForApproval)
}

@Test func serverNotificationMapsTurnStartedAndCompleted() throws {
    let started = try CodexServerNotification.decode(decodeNotification("""
    {
      "method": "turn/started",
      "params": {
        "threadId": "thread-1",
        "turnId": "turn-1",
        "startedAt": 1777588800
      }
    }
    """))
    let completed = try CodexServerNotification.decode(decodeNotification("""
    {
      "method": "turn/completed",
      "params": {
        "threadId": "thread-1",
        "turnId": "turn-1",
        "status": "completed",
        "completedAt": 1777588812
      }
    }
    """))

    guard case .turnStarted(let startedPayload) = started,
          case .turnCompleted(let completedPayload) = completed else {
        Issue.record("Expected turn lifecycle events")
        return
    }

    let startedSnapshot = CodexServerNotificationMapper.turnSnapshot(started: startedPayload)
    let completedSnapshot = CodexServerNotificationMapper.turnSnapshot(completed: completedPayload)

    #expect(startedSnapshot.id == "turn-1")
    #expect(startedSnapshot.phase == .running)
    #expect(startedSnapshot.startedAt == Date(timeIntervalSince1970: 1777588800))
    #expect(completedSnapshot.id == "turn-1")
    #expect(completedSnapshot.phase == .completed)
    #expect(completedSnapshot.completedAt == Date(timeIntervalSince1970: 1777588812))
}

@Test func serverNotificationMapsItemStartedAndCompleted() throws {
    let started = try CodexServerNotification.decode(decodeNotification("""
    {
      "method": "item/started",
      "params": {
        "threadId": "thread-1",
        "turnId": "turn-1",
        "item": {
          "id": "item-1",
          "type": "commandExecution",
          "command": "swift test",
          "status": "running"
        }
      }
    }
    """))
    let completed = try CodexServerNotification.decode(decodeNotification("""
    {
      "method": "item/completed",
      "params": {
        "threadId": "thread-1",
        "turnId": "turn-1",
        "item": {
          "id": "item-1",
          "type": "commandExecution",
          "command": "swift test",
          "status": "completed",
          "aggregatedOutput": "Test Suite passed"
        }
      }
    }
    """))

    guard case .itemStarted(let startedPayload) = started,
          case .itemCompleted(let completedPayload) = completed else {
        Issue.record("Expected item lifecycle events")
        return
    }

    let startedItem = CodexServerNotificationMapper.timelineItem(started: startedPayload)
    let completedItem = CodexServerNotificationMapper.timelineItem(completed: completedPayload)

    #expect(startedItem.kind == .commandExecution)
    #expect(startedItem.title == "Command")
    #expect(startedItem.summary == "swift test")
    #expect(completedItem.id == "item-1")
    #expect(completedItem.detail == "Test Suite passed")
}

@Test func serverNotificationMapsCommandOutputDeltaAndApprovalPlaceholder() throws {
    let outputDelta = try CodexServerNotification.decode(decodeNotification("""
    {
      "method": "command/output/delta",
      "params": {
        "threadId": "thread-1",
        "turnId": "turn-1",
        "itemId": "cmd-1",
        "delta": "Compiling SideCar\\n",
        "stream": "stdout",
        "sequence": 3
      }
    }
    """))
    let approval = try CodexServerNotification.decode(decodeNotification("""
    {
      "method": "approval/requested",
      "params": {
        "threadId": "thread-1",
        "turnId": "turn-1",
        "approvalId": "approval-1",
        "title": "Approval Requested",
        "summary": "Command requires review",
        "kind": "command"
      }
    }
    """))

    guard case .commandOutputDelta(let outputPayload) = outputDelta,
          case .approvalRequested(let approvalPayload) = approval else {
        Issue.record("Expected command output and approval events")
        return
    }

    let outputItem = CodexServerNotificationMapper.timelineItem(commandOutputDelta: outputPayload)
    let approvalItem = CodexServerNotificationMapper.timelineItem(approvalRequest: approvalPayload)

    #expect(outputItem.kind == .commandExecution)
    #expect(outputItem.title == "Command Output stdout")
    #expect(outputItem.summary == "Compiling SideCar")
    #expect(outputItem.detail == "Compiling SideCar\n")
    #expect(approvalItem.kind == .approval)
    #expect(approvalItem.id == "approval-1")
    #expect(approvalItem.summary == "Command requires review")
}

@Test func serverNotificationKeepsUnknownMethodsAsDataOnlyEvents() throws {
    let notification = try decodeNotification("""
    {
      "method": "fs/write",
      "params": {
        "path": "blocked.txt"
      }
    }
    """)

    let event = try CodexServerNotification.decode(notification)

    #expect(event == .unknown(method: "fs/write", params: .object(["path": .string("blocked.txt")])))
}

@Test func notificationPumpEmitsKnownNotification() throws {
    let pump = CodexServerNotificationPump()
    let line = jsonLineData("""
    {
      "jsonrpc": "2.0",
      "method": "turn/started",
      "params": {
        "threadId": "thread-1",
        "turnId": "turn-1",
        "startedAt": 1777588800
      }
    }
    """)

    let event = try #require(pump.consume(line: line))

    guard case .notification(.turnStarted(let payload)) = event else {
        Issue.record("Expected turn/started stream event")
        return
    }

    #expect(payload.threadId == "thread-1")
    #expect(payload.turnId == "turn-1")
}

@Test func notificationPumpKeepsUnknownNotificationMethods() throws {
    let pump = CodexServerNotificationPump()
    let line = jsonLineData("""
    {
      "jsonrpc": "2.0",
      "method": "custom/notice",
      "params": {
        "state": "warming"
      }
    }
    """)

    let event = try #require(pump.consume(line: line))

    guard case .notification(.unknown(let method, let params)) = event else {
        Issue.record("Expected unknown notification stream event")
        return
    }

    #expect(method == "custom/notice")
    #expect(params == .object(["state": .string("warming")]))
}

@Test func notificationPumpIgnoresResponsesAndRequests() throws {
    let pump = CodexServerNotificationPump()

    let response = pump.consume(line: jsonLineData("""
    {
      "jsonrpc": "2.0",
      "id": 4,
      "result": {
        "ok": true
      }
    }
    """))
    let request = pump.consume(line: jsonLineData("""
    {
      "jsonrpc": "2.0",
      "id": 5,
      "method": "thread/list",
      "params": {
        "limit": 10
      }
    }
    """))

    #expect(response == nil)
    #expect(request == nil)
}

@Test func notificationPumpSurfacesMalformedPayloadDeterministically() throws {
    let pump = CodexServerNotificationPump()
    let line = jsonLineData("""
    {
      "jsonrpc": "2.0",
      "method": "turn/started",
      "params": {
        "threadId": "thread-1"
      }
    }
    """)

    let event = try #require(pump.consume(line: line))

    guard case .malformed(let error) = event else {
        Issue.record("Expected malformed notification event")
        return
    }

    #expect(error.method == "turn/started")
    #expect(error.line.contains("\"method\":\"turn"))
    #expect(error.line.contains("started\""))
    #expect(error.line.contains("\"threadId\":\"thread-1\""))
}

@Test func notificationPumpPreservesLineOrderAcrossMixedFrames() throws {
    let pump = CodexServerNotificationPump()
    let lines = [
        jsonLineData("""
        {
          "jsonrpc": "2.0",
          "method": "thread/status/changed",
          "params": {
            "threadId": "thread-1",
            "status": "active"
          }
        }
        """),
        jsonLineData("""
        {
          "jsonrpc": "2.0",
          "id": 7,
          "result": {
            "ignored": true
          }
        }
        """),
        jsonLineData("""
        {
          "jsonrpc": "2.0",
          "method": "custom/notice",
          "params": {
            "step": 2
          }
        }
        """),
        jsonLineData("""
        {
          "jsonrpc": "2.0",
          "method": "turn/completed",
          "params": {
            "threadId": "thread-1",
            "turnId": "turn-1",
            "status": "completed"
          }
        }
        """)
    ]

    let events = lines.compactMap { pump.consume(line: $0) }

    #expect(events.count == 3)
    guard case .notification(.threadStatusChanged(let statusPayload)) = events[0] else {
        Issue.record("Expected first event to be thread/status/changed")
        return
    }
    #expect(statusPayload.threadId == "thread-1")
    #expect(statusPayload.status == "active")

    guard case .notification(.unknown(let method, let params)) = events[1] else {
        Issue.record("Expected second event to be unknown notification")
        return
    }
    #expect(method == "custom/notice")
    #expect(params == .object(["step": .number(2)]))

    guard case .notification(.turnCompleted(let completedPayload)) = events[2] else {
        Issue.record("Expected third event to be turn/completed")
        return
    }
    #expect(completedPayload.threadId == "thread-1")
    #expect(completedPayload.turnId == "turn-1")
    #expect(completedPayload.status == "completed")
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

@Test func executeLiveActionDoesNotRetryMutationAfterProxyCallFailure() throws {
    let transport = MockCodexTransport()
    transport.results = ["initialize": .object(["ok": .bool(true)])]
    transport.callErrors = ["turn/start": CodexAppServerError.malformedResponse]
    let client = CodexAppServerClient(transport: transport)
    let action = SideCarAction(
        kind: .queueMessage,
        targetThreadId: "thread-1",
        payloadPreview: "do not replay",
        actor: .userClick,
        source: .appServerLive,
        confirmationState: .confirmed
    )

    #expect(throws: CodexAppServerError.self) {
        _ = try client.executeLiveAction(action)
    }
    #expect(transport.startedModes == [.proxy])
    #expect(transport.calls.map(\.method) == ["initialize", "turn/start"])
    #expect(transport.stopCount == 1)
}

private final class MockCodexTransport: CodexAppServerTransport {
    var startedModes: [CodexAppServerLaunchMode] = []
    var stopCount = 0
    var calls: [(method: String, params: JSONValue?)] = []
    var notifications: [(method: String, params: JSONValue?)] = []
    var results: [String: JSONValue] = [:]
    var callErrors: [String: Error] = [:]

    func start(mode: CodexAppServerLaunchMode) throws {
        startedModes.append(mode)
    }

    func stop() {
        stopCount += 1
    }

    func call(method: String, params: JSONValue?) throws -> JSONValue? {
        calls.append((method, params))
        if let error = callErrors[method] {
            throw error
        }
        return results[method]
    }

    func notify(method: String, params: JSONValue?) throws {
        notifications.append((method, params))
    }
}

private func decodeNotification(_ json: String) throws -> JSONRPCNotification {
    let data = Data(json.utf8)
    return try JSONRPCCodec.decodeNotification(data)
}

private func jsonLineData(_ json: String) -> Data {
    let object = try! JSONSerialization.jsonObject(with: Data(json.utf8))
    return try! JSONSerialization.data(withJSONObject: object, options: [])
}
