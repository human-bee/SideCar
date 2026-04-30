import AppCore
import CodexAdapter
import Foundation
import Testing

@Test func notificationStreamReadsEventsInOrderUntilEOF() throws {
    let reader = MockCodexLineReader(lines: [
        jsonLineData("""
        {
          "jsonrpc": "2.0",
          "method": "turn/started",
          "params": {
            "threadId": "thread-1",
            "turnId": "turn-1",
            "startedAt": 1777588800
          }
        }
        """),
        jsonLineData("""
        {
          "jsonrpc": "2.0",
          "method": "command/output/delta",
          "params": {
            "threadId": "thread-1",
            "turnId": "turn-1",
            "itemId": "cmd-1",
            "delta": "Compiling\\n"
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
        """)
    ])
    let stream = CodexServerNotificationStream()
    var events: [CodexServerNotificationStreamEvent] = []

    try stream.consume(from: reader) { event in
        events.append(event)
    }

    #expect(events.count == 2)
    guard case .notification(.turnStarted(let started)) = events[0] else {
        Issue.record("Expected first event to be turn/started")
        return
    }
    #expect(started.turnId == "turn-1")
    guard case .notification(.commandOutputDelta(let delta)) = events[1] else {
        Issue.record("Expected second event to be command/output/delta")
        return
    }
    #expect(delta.itemId == "cmd-1")
    #expect(reader.readCount == 4)
}

@Test func notificationStreamStopsWhenRequested() throws {
    let reader = MockCodexLineReader(lines: [
        jsonLineData("""
        {
          "jsonrpc": "2.0",
          "method": "turn/started",
          "params": {
            "threadId": "thread-1",
            "turnId": "turn-1"
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
    ])
    let stream = CodexServerNotificationStream()
    var events: [CodexServerNotificationStreamEvent] = []

    try stream.consume(from: reader) { event in
        events.append(event)
        stream.stop()
    }

    #expect(events.count == 1)
    #expect(reader.readCount == 1)
}

@Test func notificationReducerTransitionsThreadFromRunningToApprovalToCompleted() {
    let base = ThreadSnapshot(
        id: "thread-1",
        title: "Live thread",
        status: .running,
        freshness: Freshness(capturedAt: Date(timeIntervalSince1970: 100), source: .appServerLive),
        summary: "Running"
    )

    let events: [CodexServerNotification] = [
        .turnStarted(.init(threadId: "thread-1", turnId: "turn-1", startedAt: 1777588800)),
        .itemStarted(.init(
            threadId: "thread-1",
            turnId: "turn-1",
            item: .init(id: "cmd-1", type: "commandExecution", command: "swift test", status: "running")
        )),
        .commandOutputDelta(.init(
            threadId: "thread-1",
            turnId: "turn-1",
            itemId: "cmd-1",
            delta: "Compiling SideCar\n",
            stream: "stdout",
            sequence: 1
        )),
        .approvalRequested(.init(
            threadId: "thread-1",
            turnId: "turn-1",
            approvalId: "approval-1",
            title: "Approval Requested",
            summary: "Command requires review",
            kind: "command"
        )),
        .threadStatusChanged(.init(
            threadId: "thread-1",
            status: "active",
            activeFlags: ["waitingOnApproval"],
            updatedAt: 1777588805
        )),
        .itemCompleted(.init(
            threadId: "thread-1",
            turnId: "turn-1",
            item: .init(
                id: "cmd-1",
                type: "commandExecution",
                command: "swift test",
                status: "completed",
                aggregatedOutput: "Build finished"
            )
        )),
        .turnCompleted(.init(
            threadId: "thread-1",
            turnId: "turn-1",
            status: "completed",
            completedAt: 1777588812
        )),
        .threadStatusChanged(.init(
            threadId: "thread-1",
            status: "completed",
            activeFlags: [],
            updatedAt: 1777588812
        ))
    ]

    let reduced = events.reduce([base]) { snapshots, event in
        CodexThreadSnapshotReducer.apply(event, to: snapshots)
    }

    let thread = reduced[0]
    guard let turn = thread.currentTurn else {
        Issue.record("Expected current turn")
        return
    }
    #expect(thread.status == .completed)
    #expect(thread.freshness.capturedAt == Date(timeIntervalSince1970: 1777588812))
    #expect(turn.phase == .completed)
    #expect(turn.startedAt == Date(timeIntervalSince1970: 1777588800))
    #expect(turn.completedAt == Date(timeIntervalSince1970: 1777588812))
    #expect(turn.blockers.map { $0.id } == ["approval-1"])
    #expect(turn.blockers.first?.kind == .approval)
    #expect(turn.itemGroups.map { $0.id } == ["cmd-1", "approval-1"])
    #expect(turn.itemGroups.first?.detail == "Build finished")
}

@Test func notificationReducerUpdatesExistingTurnAndIgnoresUnknownThread() {
    let snapshots = [
        ThreadSnapshot(
            id: "thread-1",
            title: "Live thread",
            status: .running,
            freshness: Freshness(capturedAt: Date(timeIntervalSince1970: 100), source: .appServerLive),
            currentTurn: TurnSnapshot(id: "turn-1", phase: .running, itemGroups: [
                TimelineItem(
                    id: "cmd-1",
                    kind: .commandExecution,
                    title: "Command",
                    summary: "swift test",
                    detail: "Compiling",
                    createdAt: Date(timeIntervalSince1970: 101),
                    source: .appServerLive
                )
            ]),
            summary: "Running"
        )
    ]

    let reduced = CodexThreadSnapshotReducer.apply(.commandOutputDelta(.init(
        threadId: "thread-1",
        turnId: "turn-1",
        itemId: "cmd-1",
        delta: " finished\n",
        stream: "stdout",
        sequence: 2
    )), to: snapshots)
    let ignored = CodexThreadSnapshotReducer.apply(.turnStarted(.init(
        threadId: "thread-2",
        turnId: "turn-x",
        startedAt: nil
    )), to: reduced)

    #expect(ignored.count == 1)
    #expect(ignored[0].currentTurn?.itemGroups.first?.detail == "Compiling finished\n")
}

private final class MockCodexLineReader: CodexLineReadable {
    private var remaining: [Data]
    var readCount = 0

    init(lines: [Data]) {
        self.remaining = lines
    }

    func readLine() throws -> Data? {
        readCount += 1
        guard !remaining.isEmpty else {
            return nil
        }
        return remaining.removeFirst()
    }
}

private func jsonLineData(_ json: String) -> Data {
    let object = try! JSONSerialization.jsonObject(with: Data(json.utf8))
    return try! JSONSerialization.data(withJSONObject: object, options: [])
}
