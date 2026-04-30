import AppCore
import ThreadStore
import UIComponents
import XCTest

@MainActor
final class SideCarViewModelTests: XCTestCase {
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
