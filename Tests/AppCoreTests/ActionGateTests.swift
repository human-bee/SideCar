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
