import AppCore
import ThreadStore
import UIComponents
import VoiceCore
import XCTest

@MainActor
final class SideCarViewModelTests: XCTestCase {
    func testCheckRealtimeUsesInjectedStatusClientAndPublishesReadyDiagnostic() async {
        let client = StubRealtimeStatusClient(
            currentStatus: .ready(model: "gpt-realtime-1.5"),
            checkedStatus: .active(model: "gpt-realtime-1.5", createdAt: Date(timeIntervalSince1970: 1_234))
        )
        let viewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: Self.threadFixtures),
            realtimeStatusClient: client,
            openAIKeyAvailable: { true }
        )

        XCTAssertEqual(viewModel.realtimeReadiness.state, .ready)

        await viewModel.checkRealtimeReadiness()

        XCTAssertEqual(client.checkCallCount, 1)
        XCTAssertEqual(viewModel.realtimeReadiness.state, .active)
        XCTAssertEqual(viewModel.realtimeReadiness.diagnostic, "Realtime gpt-realtime-1.5 active")
    }

    func testCapturePreviewCreatesUnsentMetadataOnlyBundle() throws {
        let previewURL = URL(fileURLWithPath: "/tmp/sidecar-preview.png")
        let viewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: Self.threadFixtures),
            screenPreviewCoordinator: StubScreenPreviewCoordinator(
                permission: .granted,
                capturedBundle: VisualContextBundle(
                    displayName: "Main display",
                    imagePath: previewURL.path,
                    previewAccepted: false,
                    sentToModel: false
                )
            ),
            openAIKeyAvailable: { false }
        )

        try viewModel.capturePreview()

        XCTAssertEqual(viewModel.previewBundle?.displayName, "Main display")
        XCTAssertEqual(viewModel.previewBundle?.imagePath, previewURL.path)
        XCTAssertEqual(viewModel.previewBundle?.previewAccepted, false)
        XCTAssertEqual(viewModel.previewBundle?.sentToModel, false)
    }

    func testAcceptPreviewMarksAcceptedWithoutMarkingSentToModel() throws {
        let previewURL = URL(fileURLWithPath: "/tmp/sidecar-preview.png")
        let acceptedBundle = VisualContextBundle(
            displayName: "Main display",
            imagePath: previewURL.path,
            previewAccepted: true,
            sentToModel: false
        )
        let coordinator = StubScreenPreviewCoordinator(
            permission: .granted,
            capturedBundle: VisualContextBundle(
                displayName: "Main display",
                imagePath: previewURL.path,
                previewAccepted: false,
                sentToModel: false
            ),
            acceptedBundle: acceptedBundle
        )
        let viewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: Self.threadFixtures),
            screenPreviewCoordinator: coordinator,
            openAIKeyAvailable: { false }
        )
        try viewModel.capturePreview()

        viewModel.acceptPreview()

        XCTAssertEqual(viewModel.previewBundle, acceptedBundle)
        XCTAssertEqual(coordinator.acceptCallCount, 1)
    }

    func testSaveOpenAIKeyUsesInjectedBrokerAndClearsDraft() {
        var savedKey: String?
        let viewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: Self.threadFixtures),
            saveOpenAIKey: { savedKey = $0 },
            openAIKeyAvailable: { false }
        )

        viewModel.openAIKeyDraft = "  sk-test-value  "
        viewModel.saveOpenAIKeyDraft()

        XCTAssertEqual(savedKey, "sk-test-value")
        XCTAssertEqual(viewModel.openAIKeyDraft, "")
        XCTAssertEqual(viewModel.openAIKeyStatus, .saved("OpenAI key saved to Keychain"))
    }

    func testSourceDiagnosticsDistinguishesFixtureFromLive() {
        let viewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: Self.threadFixtures),
            openAIKeyAvailable: { true }
        )
        viewModel.updateCapabilityProbe(CapabilityProbe(
            appServerAvailable: true,
            supportedMethods: ["thread.list", "thread.active"],
            transport: "app-server",
            notes: ["probe ok"]
        ))

        XCTAssertEqual(viewModel.sourceDiagnostics.sourceLabel, "Live source")
        XCTAssertTrue(viewModel.sourceDiagnostics.isLive)
        XCTAssertTrue(viewModel.sourceDiagnostics.notes.contains("2 app-server methods reported"))
    }

    func testThreadSelectionAndGrouping() {
        let viewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: Self.threadFixtures),
            openAIKeyAvailable: { false }
        )

        viewModel.selectThread("waiting")

        XCTAssertEqual(viewModel.activeThread.id, "waiting")
        XCTAssertEqual(viewModel.groupedThreads.map(\.kind), [.needsAttention, .running, .completed, .stale])
        XCTAssertEqual(viewModel.groupedThreads.first?.threads.map(\.id), ["waiting"])
    }

    func testConfirmStagedActionUsesLiveExecutor() async {
        let executedAction = ActionRecorder()
        let viewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: Self.threadFixtures),
            openAIKeyAvailable: { false }
        )
        viewModel.liveActionExecutor = { action in
            await executedAction.record(action)
            return "ok"
        }

        viewModel.chatDraft = "queue this"
        viewModel.stageMessage()
        viewModel.confirmStagedAction()

        try? await Task.sleep(nanoseconds: 50_000_000)
        let recordedAction = await executedAction.currentAction()
        XCTAssertEqual(recordedAction?.kind, .queueMessage)
        XCTAssertEqual(viewModel.stagedAction?.confirmationState, .executed)
        XCTAssertTrue(viewModel.stagedAction?.payloadPreview.contains("Sent to live Codex app-server.") == true)
    }

    func testReloadTimeoutKeepsFixtureDataWhenLiveSourceHangs() async {
        let viewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: Self.threadFixtures),
            openAIKeyAvailable: { false }
        )
        viewModel.liveReloadTimeoutNanoseconds = 10_000_000
        viewModel.liveReload = {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            return (Self.threadFixtures, CapabilityProbe(appServerAvailable: true, transport: "app-server"))
        }

        viewModel.reloadFromBestAvailableSource()

        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertFalse(viewModel.isReloading)
        XCTAssertEqual(viewModel.activeThread.id, SampleData.activeThread.id)
        XCTAssertEqual(viewModel.capabilityProbe.transport, "fixture")
        XCTAssertEqual(viewModel.capabilityProbe.appServerAvailable, false)
        XCTAssertTrue(viewModel.capabilityProbe.notes.contains("Live app-server reload timed out; staying in fixture mode."))
    }

    func testOverlappingReloadsKeepLatestResult() async {
        let sequence = ReloadSequence()
        let oldThread = ThreadSnapshot(
            id: "old-live",
            title: "Old live",
            status: .running,
            freshness: Freshness(source: .appServerLive),
            summary: "Older response"
        )
        let newThread = ThreadSnapshot(
            id: "new-live",
            title: "New live",
            status: .running,
            freshness: Freshness(source: .appServerLive),
            summary: "Newer response"
        )
        let viewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: Self.threadFixtures),
            openAIKeyAvailable: { false }
        )
        viewModel.liveReloadTimeoutNanoseconds = 500_000_000
        viewModel.liveReload = {
            await sequence.next(oldThread: oldThread, newThread: newThread)
        }

        viewModel.reloadFromBestAvailableSource()
        try? await Task.sleep(nanoseconds: 5_000_000)
        viewModel.reloadFromBestAvailableSource()

        try? await Task.sleep(nanoseconds: 130_000_000)
        XCTAssertEqual(viewModel.activeThread.id, "new-live")
        XCTAssertEqual(viewModel.capabilityProbe.transport, "latest")
    }

    func testPendingApprovalsPreferBlockersAndFallbackToTimelineItems() {
        let blockingApproval = TimelineItem(
            id: "approval-blocker",
            kind: .approval,
            title: "Approve shell command",
            summary: "Needs explicit review",
            source: .appServerLive
        )
        let timelineApproval = TimelineItem(
            id: "approval-item",
            kind: .approval,
            title: "Approve network access",
            summary: "Allow loopback-only request",
            source: .appServerLive
        )
        let thread = ThreadSnapshot(
            id: "approval-thread",
            title: "Approval thread",
            status: .waitingForApproval,
            freshness: Freshness(source: .appServerLive),
            currentTurn: TurnSnapshot(
                id: "turn-approval",
                phase: .waitingForApproval,
                itemGroups: [timelineApproval],
                blockers: [blockingApproval]
            ),
            summary: "Waiting"
        )
        let fallbackThread = ThreadSnapshot(
            id: "fallback-thread",
            title: "Fallback thread",
            status: .waitingForApproval,
            freshness: Freshness(source: .appServerLive),
            currentTurn: TurnSnapshot(
                id: "turn-fallback",
                phase: .waitingForApproval,
                itemGroups: [timelineApproval],
                blockers: []
            ),
            summary: "Waiting"
        )

        let blockingViewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: [thread]),
            openAIKeyAvailable: { false }
        )
        let fallbackViewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: [fallbackThread]),
            openAIKeyAvailable: { false }
        )

        XCTAssertEqual(blockingViewModel.pendingApprovalCenter?.count, 1)
        XCTAssertEqual(blockingViewModel.pendingApprovalCenter?.items.map(\.id), ["approval-blocker"])
        XCTAssertEqual(fallbackViewModel.pendingApprovalCenter?.items.map(\.id), ["approval-item"])
    }

    func testStageApprovalDecisionIncludesScopeAndRequiresConfirmation() {
        let approval = TimelineItem(
            id: "approval-item",
            kind: .approval,
            title: "Approve file write",
            summary: "Allow editing Sources/UIComponents/SideCarRootView.swift",
            source: .appServerLive
        )
        let thread = ThreadSnapshot(
            id: "approval-thread",
            title: "Approval thread",
            status: .waitingForApproval,
            freshness: Freshness(source: .appServerLive),
            currentTurn: TurnSnapshot(
                id: "turn-approval",
                phase: .waitingForApproval,
                itemGroups: [approval],
                blockers: [approval]
            ),
            summary: "Waiting"
        )
        let viewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: [thread]),
            openAIKeyAvailable: { false }
        )

        viewModel.stageApprovalDecision(approved: true, itemID: approval.id)

        XCTAssertEqual(viewModel.stagedAction?.kind, .approvalDecision)
        XCTAssertEqual(viewModel.stagedAction?.targetThreadId, "approval-thread")
        XCTAssertEqual(viewModel.stagedAction?.targetTurnId, "turn-approval")
        XCTAssertEqual(viewModel.stagedAction?.confirmationState, .staged)
        XCTAssertTrue(viewModel.stagedAction?.payloadPreview.contains("Accept") == true)
        XCTAssertTrue(viewModel.stagedAction?.payloadPreview.contains("approval item: approval-item") == true)
        XCTAssertTrue(viewModel.stagedAction?.payloadPreview.contains("Approve file write") == true)
        XCTAssertTrue(viewModel.stagedAction?.payloadPreview.contains("Allow editing Sources/UIComponents/SideCarRootView.swift") == true)
    }

    func testConfirmApprovalDecisionDoesNotUseLiveExecutor() async {
        let executedAction = ActionRecorder()
        let approval = TimelineItem(
            id: "approval-item",
            kind: .approval,
            title: "Approve command",
            summary: "Run tool",
            source: .appServerLive
        )
        let thread = ThreadSnapshot(
            id: "approval-thread",
            title: "Approval thread",
            status: .waitingForApproval,
            freshness: Freshness(source: .appServerLive),
            currentTurn: TurnSnapshot(
                id: "turn-approval",
                phase: .waitingForApproval,
                itemGroups: [approval],
                blockers: [approval]
            ),
            summary: "Waiting"
        )
        let viewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: [thread]),
            openAIKeyAvailable: { false }
        )
        viewModel.liveActionExecutor = { action in
            await executedAction.record(action)
            return "should not send"
        }

        viewModel.stageApprovalDecision(approved: false, itemID: approval.id)
        viewModel.confirmStagedAction()

        try? await Task.sleep(nanoseconds: 50_000_000)
        let recordedAction = await executedAction.currentAction()
        XCTAssertNil(recordedAction)
        XCTAssertEqual(viewModel.stagedAction?.confirmationState, .failed)
        XCTAssertTrue(viewModel.stagedAction?.payloadPreview.contains("server-request response plumbing") == true)
    }

    nonisolated private static let threadFixtures: [ThreadSnapshot] = [
        ThreadSnapshot(
            id: "live",
            title: "Live thread",
            status: .running,
            freshness: Freshness(source: .appServerLive),
            summary: "Running"
        ),
        ThreadSnapshot(
            id: "waiting",
            title: "Approval thread",
            status: .waitingForApproval,
            freshness: Freshness(source: .appServerLive),
            summary: "Needs approval"
        ),
        ThreadSnapshot(
            id: "done",
            title: "Done thread",
            status: .completed,
            freshness: Freshness(source: .appServerLive),
            summary: "Complete"
        ),
        ThreadSnapshot(
            id: "old",
            title: "Stale thread",
            status: .running,
            freshness: Freshness(source: .fixture, isStale: true),
            summary: "Old"
        )
    ]
}

private actor ActionRecorder {
    private(set) var action: SideCarAction?

    func record(_ action: SideCarAction) {
        self.action = action
    }

    func currentAction() -> SideCarAction? {
        action
    }
}

private final class StubRealtimeStatusClient: RealtimeStatusClient, @unchecked Sendable {
    let currentStatus: RealtimeSessionStatus
    let checkedStatus: RealtimeSessionStatus
    private(set) var checkCallCount = 0

    init(currentStatus: RealtimeSessionStatus, checkedStatus: RealtimeSessionStatus) {
        self.currentStatus = currentStatus
        self.checkedStatus = checkedStatus
    }

    func currentRealtimeStatus(model: String) -> RealtimeSessionStatus {
        currentStatus
    }

    func checkRealtimeStatus(model: String) async -> RealtimeSessionStatus {
        checkCallCount += 1
        return checkedStatus
    }
}

private final class StubScreenPreviewCoordinator: ScreenPreviewCoordinating {
    let permission: ScreenCapturePermissionState
    let capturedBundle: VisualContextBundle
    let acceptedBundle: VisualContextBundle
    private(set) var acceptCallCount = 0

    init(
        permission: ScreenCapturePermissionState,
        capturedBundle: VisualContextBundle,
        acceptedBundle: VisualContextBundle? = nil
    ) {
        self.permission = permission
        self.capturedBundle = capturedBundle
        self.acceptedBundle = acceptedBundle ?? capturedBundle
    }

    func permissionState() -> ScreenCapturePermissionState {
        permission
    }

    func requestPermission() -> Bool {
        true
    }

    func capturePreviewBundle(displayName: String) throws -> VisualContextBundle {
        capturedBundle
    }

    func markPreviewAccepted(_ bundle: VisualContextBundle) -> VisualContextBundle {
        acceptCallCount += 1
        return acceptedBundle
    }
}

private actor ReloadSequence {
    private var count = 0

    func next(oldThread: ThreadSnapshot, newThread: ThreadSnapshot) async -> ([ThreadSnapshot], CapabilityProbe) {
        count += 1
        if count == 1 {
            try? await Task.sleep(nanoseconds: 80_000_000)
            return ([oldThread], CapabilityProbe(appServerAvailable: true, transport: "older"))
        }
        return ([newThread], CapabilityProbe(appServerAvailable: true, transport: "latest"))
    }
}

private final class StubThreadRepository: ThreadRepository {
    private let threads: [ThreadSnapshot]

    init(threads: [ThreadSnapshot]) {
        self.threads = threads
    }

    func activeThread() -> ThreadSnapshot {
        threads[0]
    }

    func allThreads() -> [ThreadSnapshot] {
        threads
    }

    func search(_ query: String) -> [ThreadSnapshot] {
        threads
    }
}
