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
        var executedAction: SideCarAction?
        let viewModel = SideCarViewModel(
            repository: StubThreadRepository(threads: Self.threadFixtures),
            openAIKeyAvailable: { false }
        )
        viewModel.liveActionExecutor = { action in
            executedAction = action
            return "ok"
        }

        viewModel.chatDraft = "queue this"
        viewModel.stageMessage()
        viewModel.confirmStagedAction()

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(executedAction?.kind, .queueMessage)
        XCTAssertEqual(viewModel.stagedAction?.confirmationState, .executed)
        XCTAssertTrue(viewModel.stagedAction?.payloadPreview.contains("Sent to live Codex app-server.") == true)
    }

    private static let threadFixtures: [ThreadSnapshot] = [
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
