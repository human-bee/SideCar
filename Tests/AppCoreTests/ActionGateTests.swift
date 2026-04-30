import AppCore
import Testing

@Test func queuedMessageRequiresConfirmationBeforeExecution() throws {
    let thread = SampleData.activeThread
    let gate = ActionGate()
    let action = SideCarAction(
        kind: .queueMessage,
        targetThreadId: thread.id,
        payloadPreview: "Follow up later",
        actor: .userClick,
        source: .fixture,
        confirmationState: .staged
    )

    try gate.validateForStaging(action, activeThread: thread)
    #expect(throws: ActionGateError.confirmationRequired) {
        try gate.validateForExecution(action, activeThread: thread)
    }
}

@Test func steerRequiresTurnId() throws {
    let thread = SampleData.activeThread
    let gate = ActionGate()
    let action = SideCarAction(
        kind: .steerTurn,
        targetThreadId: thread.id,
        targetTurnId: nil,
        payloadPreview: "Steer this",
        actor: .voice,
        source: .fixture,
        confirmationState: .confirmed
    )

    #expect(throws: ActionGateError.missingTurnId(.steerTurn)) {
        try gate.validateForExecution(action, activeThread: thread)
    }
}

@Test func unsafeCapabilitiesAreRejected() throws {
    let gate = ActionGate()
    #expect(throws: ActionGateError.unsafeCapability("thread/shellCommand")) {
        try gate.validateCapability("thread/shellCommand")
    }
}

@Test func pendingApprovalCenterFallsBackFromBlockersToTimelineItems() {
    let approval = TimelineItem(
        id: "approval-1",
        kind: .approval,
        title: "Approve patch",
        summary: "Apply SideCarRootView change",
        source: .fixture
    )
    let blockerThread = ThreadSnapshot(
        id: "thread-1",
        title: "Blocking approval",
        status: .waitingForApproval,
        freshness: Freshness(source: .fixture),
        currentTurn: TurnSnapshot(
            id: "turn-1",
            phase: .waitingForApproval,
            itemGroups: [],
            blockers: [approval]
        ),
        summary: "Waiting"
    )
    let timelineThread = ThreadSnapshot(
        id: "thread-2",
        title: "Timeline approval",
        status: .waitingForApproval,
        freshness: Freshness(source: .fixture),
        currentTurn: TurnSnapshot(
            id: "turn-2",
            phase: .waitingForApproval,
            itemGroups: [approval],
            blockers: []
        ),
        summary: "Waiting"
    )

    let blockerCenter = PendingApprovalCenter(thread: blockerThread)
    let timelineCenter = PendingApprovalCenter(thread: timelineThread)

    #expect(blockerCenter?.items.map(\.id) == ["approval-1"])
    #expect(timelineCenter?.items.map(\.id) == ["approval-1"])
}
