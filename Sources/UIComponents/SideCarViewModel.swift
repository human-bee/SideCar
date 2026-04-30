import AppCore
import Combine
import ThreadStore
import VoiceCore

private typealias ReloadResult = ([ThreadSnapshot], CapabilityProbe)

public enum RealtimeReadinessState: Equatable {
    case missingKey
    case ready
    case active
    case failed
}

public struct RealtimeReadiness: Equatable {
    public var state: RealtimeReadinessState
    public var diagnostic: String

    public init(state: RealtimeReadinessState, diagnostic: String) {
        self.state = state
        self.diagnostic = diagnostic
    }
}

@MainActor
public final class SideCarViewModel: ObservableObject {
    @Published public private(set) var activeThread: ThreadSnapshot
    @Published public private(set) var threads: [ThreadSnapshot]
    @Published public var selectedBottomTab: BottomTab = .active
    @Published public var timelineZoom: Double = 0.35
    @Published public var stagedAction: SideCarAction?
    @Published public var chatDraft: String = ""
    @Published public var speechToSpeechEnabled = false
    @Published public var screenPermission: ScreenCapturePermissionState
    @Published public var capabilityProbe = CapabilityProbe(transport: "fixture", notes: ["Fixture mode"])
    @Published public var isReloading = false
    @Published public var openAIKeyDraft = ""
    @Published public private(set) var openAIKeyStatus: SettingsStatus
    @Published public private(set) var selectedThreadId: ThreadSnapshot.ID?
    @Published public private(set) var realtimeReadiness: RealtimeReadiness
    @Published public private(set) var previewBundle: VisualContextBundle?

    public var liveReload: (@Sendable () async -> ([ThreadSnapshot], CapabilityProbe))?
    public var liveActionExecutor: (@Sendable (SideCarAction) async throws -> String?)?
    public var liveReloadTimeoutNanoseconds: UInt64 = 1_500_000_000

    private let repository: ThreadRepository
    private let actionGate = ActionGate()
    private let screenPreviewCoordinator: ScreenPreviewCoordinating
    private let realtimeStatusClient: RealtimeStatusClient
    private let saveOpenAIKey: (String) throws -> Void
    private let openAIKeyAvailable: () -> Bool
    private var reloadGeneration = 0

    public init(
        repository: ThreadRepository = FixtureThreadRepository(),
        realtimeTokenBroker: RealtimeTokenBroker = RealtimeTokenBroker(),
        realtimeStatusClient: RealtimeStatusClient? = nil,
        screenPreviewCoordinator: ScreenPreviewCoordinating = ScreenContextCoordinator(),
        saveOpenAIKey: ((String) throws -> Void)? = nil,
        openAIKeyAvailable: (() -> Bool)? = nil
    ) {
        let initialActiveThread = repository.activeThread()
        let initialThreads = repository.allThreads()
        let keyAvailable = openAIKeyAvailable ?? {
            realtimeTokenBroker.apiKeyAvailable()
        }
        let initialKeyStatus: SettingsStatus = keyAvailable() ? .saved("OpenAI key available") : .needsAttention("OpenAI key not configured")
        let initialScreenPermission = screenPreviewCoordinator.permissionState()
        let realtimeClient = realtimeStatusClient ?? realtimeTokenBroker
        let initialRealtimeReadiness = Self.readiness(from: realtimeClient.currentRealtimeStatus(model: RealtimeTokenBroker.defaultRealtimeModel))

        self.repository = repository
        self.realtimeStatusClient = realtimeClient
        self.screenPreviewCoordinator = screenPreviewCoordinator
        self.saveOpenAIKey = saveOpenAIKey ?? { key in
            try realtimeTokenBroker.saveAPIKey(key)
        }
        self.openAIKeyAvailable = keyAvailable
        self.activeThread = initialActiveThread
        self.threads = initialThreads
        self.screenPermission = initialScreenPermission
        self.selectedThreadId = initialActiveThread.id
        self.openAIKeyStatus = initialKeyStatus
        self.realtimeReadiness = initialRealtimeReadiness
    }

    public func refreshFixtures() {
        activeThread = repository.activeThread()
        threads = repository.allThreads()
        screenPermission = screenPreviewCoordinator.permissionState()
        selectedThreadId = activeThread.id
    }

    public func updateCapabilityProbe(_ probe: CapabilityProbe) {
        capabilityProbe = probe
    }

    public func applySnapshots(_ snapshots: [ThreadSnapshot]) {
        guard !snapshots.isEmpty else { return }
        threads = snapshots
        if let selectedThreadId, let selected = snapshots.first(where: { $0.id == selectedThreadId }) {
            activeThread = selected
        } else {
            activeThread = snapshots[0]
            selectedThreadId = snapshots[0].id
        }
    }

    public func reloadFromBestAvailableSource() {
        guard let liveReload else {
            refreshFixtures()
            return
        }
        reloadGeneration += 1
        let generation = reloadGeneration
        isReloading = true
        Task {
            let (snapshots, probe) = await boundedLiveReload(liveReload)
            guard generation == reloadGeneration else { return }
            applySnapshots(snapshots)
            updateCapabilityProbe(probe)
            isReloading = false
        }
    }

    private func boundedLiveReload(_ reload: @escaping @Sendable () async -> ReloadResult) async -> ReloadResult {
        let race = LiveReloadRace()
        let timeout = liveReloadTimeoutNanoseconds
        Task.detached(priority: .utility) {
            await race.finish(reload())
        }
        Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: timeout)
            await race.finish(Self.fixtureReloadResult(note: "Live app-server reload timed out; staying in fixture mode."))
        }
        return await race.value()
    }

    nonisolated private static func fixtureReloadResult(note: String) -> ReloadResult {
        (
            [SampleData.activeThread] + SampleData.backgroundThreads,
            CapabilityProbe(
                appServerAvailable: false,
                transport: "fixture",
                notes: [note]
            )
        )
    }

    public func stageMessage(asSteer: Bool = false) {
        let trimmed = chatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let kind: SideCarActionKind = asSteer ? .steerTurn : .queueMessage
        let action = SideCarAction(
            kind: kind,
            targetThreadId: activeThread.id,
            targetTurnId: asSteer ? activeThread.currentTurn?.id : nil,
            payloadPreview: trimmed,
            actor: .userClick,
            source: activeThread.freshness.source,
            confirmationState: .staged
        )
        do {
            try actionGate.validateForStaging(action, activeThread: activeThread)
            stagedAction = action
            chatDraft = ""
        } catch {
            stagedAction = SideCarAction(
                kind: .queueMessage,
                targetThreadId: activeThread.id,
                payloadPreview: "Could not stage action: \(error)",
                actor: .system,
                source: activeThread.freshness.source,
                confirmationState: .failed
            )
        }
    }

    public func stageSideQuestion() {
        let trimmed = chatDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let action = SideCarAction(
            kind: .sideQuestion,
            targetThreadId: activeThread.id,
            targetTurnId: nil,
            payloadPreview: trimmed,
            actor: .userClick,
            source: activeThread.freshness.source,
            confirmationState: .staged
        )
        do {
            try actionGate.validateForStaging(action, activeThread: activeThread)
            stagedAction = action
            chatDraft = ""
        } catch {
            stagedAction = SideCarAction(
                kind: .sideQuestion,
                targetThreadId: activeThread.id,
                payloadPreview: "Could not stage side question: \(error)",
                actor: .system,
                source: activeThread.freshness.source,
                confirmationState: .failed
            )
        }
    }

    public func stage(_ kind: SideCarActionKind) {
        let action = SideCarAction(
            kind: kind,
            targetThreadId: activeThread.id,
            targetTurnId: kind == .sideQuestion ? nil : activeThread.currentTurn?.id,
            payloadPreview: defaultPayload(for: kind),
            actor: .userClick,
            source: activeThread.freshness.source,
            confirmationState: .staged
        )
        do {
            try actionGate.validateForStaging(action, activeThread: activeThread)
            stagedAction = action
        } catch {
            stagedAction = SideCarAction(
                kind: kind,
                targetThreadId: activeThread.id,
                targetTurnId: kind == .sideQuestion ? nil : activeThread.currentTurn?.id,
                payloadPreview: "Could not stage action: \(error)",
                actor: .system,
                source: activeThread.freshness.source,
                confirmationState: .failed
            )
        }
    }

    public func confirmStagedAction() {
        guard var action = stagedAction else { return }
        if action.kind == .approvalDecision {
            action.confirmationState = .failed
            action.payloadPreview += "\n\nApproval execution is not sent yet. Codex app-server approvals are server-initiated JSON-RPC requests and require request-id response plumbing before SideCar can safely accept or decline them."
            stagedAction = action
            return
        }
        action.confirmationState = .confirmed
        do {
            try actionGate.validateForExecution(action, activeThread: activeThread)
            guard let liveActionExecutor else {
                action.confirmationState = .executed
                action.payloadPreview += "\n\nFixture mode: action passed gates but was not sent to live Codex app-server."
                stagedAction = action
                return
            }
            stagedAction = action
            Task {
                do {
                    let result = try await liveActionExecutor(action)
                    action.confirmationState = .executed
                    action.payloadPreview += "\n\nSent to live Codex app-server."
                    if let result, !result.isEmpty {
                        action.payloadPreview += "\n\(result)"
                    }
                    stagedAction = action
                    reloadFromBestAvailableSource()
                } catch {
                    action.confirmationState = .failed
                    action.payloadPreview += "\n\nLive app-server action failed: \(error)"
                    stagedAction = action
                }
            }
        } catch {
            action.confirmationState = .failed
            action.payloadPreview += "\n\n\(error)"
            stagedAction = action
        }
    }

    public func dismissStagedAction() {
        stagedAction = nil
    }

    public func requestScreenCapturePermission() {
        _ = screenPreviewCoordinator.requestPermission()
        screenPermission = screenPreviewCoordinator.permissionState()
    }

    public func checkRealtimeReadiness() async {
        realtimeReadiness = Self.readiness(from: await realtimeStatusClient.checkRealtimeStatus(model: RealtimeTokenBroker.defaultRealtimeModel))
    }

    public func startRealtimeVoiceSession() async {
        selectedBottomTab = .talk
        await checkRealtimeReadiness()
    }

    public func capturePreview(displayName: String = "Main display") throws {
        previewBundle = try screenPreviewCoordinator.capturePreviewBundle(displayName: displayName)
    }

    public func acceptPreview() {
        guard let previewBundle else { return }
        self.previewBundle = screenPreviewCoordinator.markPreviewAccepted(previewBundle)
    }

    public func clearPreview() {
        previewBundle = nil
    }

    public func selectThread(_ id: ThreadSnapshot.ID) {
        guard let selected = threads.first(where: { $0.id == id }) else { return }
        activeThread = selected
        selectedThreadId = id
    }

    public func saveOpenAIKeyDraft() {
        let trimmed = openAIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            openAIKeyStatus = .needsAttention("Paste an OpenAI API key before saving")
            return
        }
        do {
            try saveOpenAIKey(trimmed)
            openAIKeyDraft = ""
            openAIKeyStatus = .saved("OpenAI key saved to Keychain")
        } catch {
            openAIKeyStatus = .failed("Could not save key: \(error)")
        }
    }

    public var sourceDiagnostics: SourceDiagnostics {
        SourceDiagnostics(activeThread: activeThread, probe: capabilityProbe)
    }

    public var pendingApprovalCenter: PendingApprovalCenter? {
        PendingApprovalCenter(thread: activeThread)
    }

    public var groupedThreads: [ThreadGroup] {
        let order: [ThreadGroupKind] = [.needsAttention, .running, .idle, .completed, .stale]
        let grouped = Dictionary(grouping: threads, by: ThreadGroupKind.init(thread:))
        return order.compactMap { kind in
            guard let threads = grouped[kind], !threads.isEmpty else { return nil }
            return ThreadGroup(kind: kind, threads: threads)
        }
    }

    private func defaultPayload(for kind: SideCarActionKind) -> String {
        switch kind {
        case .queueMessage:
            return "Queue a follow-up message for this thread."
        case .sideQuestion:
            return "Ask a /side tangent without steering the parent thread."
        case .steerTurn:
            return "Steer the active turn with a concise instruction."
        case .forkThread:
            return "Fork this thread for a tangent investigation."
        case .interruptTurn:
            return "Interrupt the currently running turn."
        case .startReview:
            return "Start a review pass on the current thread context."
        case .compactThread:
            return "Compact this thread context."
        case .approvalDecision:
            return "Respond to the pending approval."
        }
    }

    public func stageApprovalDecision(approved: Bool, itemID: TimelineItem.ID) {
        guard
            let center = pendingApprovalCenter,
            let item = center.items.first(where: { $0.id == itemID })
        else {
            stagedAction = SideCarAction(
                kind: .approvalDecision,
                targetThreadId: activeThread.id,
                targetTurnId: activeThread.currentTurn?.id,
                payloadPreview: "Could not stage action: approval item is no longer available.",
                actor: .system,
                source: activeThread.freshness.source,
                confirmationState: .failed
            )
            return
        }

        let decision = approved ? "Accept" : "Decline"
        let summaryLines = [
            "\(decision) approval decision",
            "thread: \(center.scope.threadId)",
            "turn: \(center.scope.turnId)",
            "approval item: \(item.id)",
            "title: \(item.title)",
            "summary: \(item.summary)",
            "status: staged only until app-server server-request response plumbing is implemented"
        ]
        let action = SideCarAction(
            kind: .approvalDecision,
            targetThreadId: center.scope.threadId,
            targetTurnId: center.scope.turnId,
            payloadPreview: summaryLines.joined(separator: "\n"),
            actor: .userClick,
            source: activeThread.freshness.source,
            confirmationState: .staged
        )

        do {
            try actionGate.validateForStaging(action, activeThread: activeThread)
            stagedAction = action
        } catch {
            stagedAction = SideCarAction(
                kind: .approvalDecision,
                targetThreadId: center.scope.threadId,
                targetTurnId: center.scope.turnId,
                payloadPreview: "Could not stage action: \(error)",
                actor: .system,
                source: activeThread.freshness.source,
                confirmationState: .failed
            )
        }
    }

    private static func readiness(from status: RealtimeSessionStatus) -> RealtimeReadiness {
        switch status {
        case .missingAPIKey:
            return RealtimeReadiness(state: .missingKey, diagnostic: "OpenAI API key missing")
        case .ready(let model):
            return RealtimeReadiness(state: .ready, diagnostic: "Realtime \(model) ready")
        case .minting(let model):
            return RealtimeReadiness(state: .ready, diagnostic: "Realtime \(model) check in progress")
        case .active(let model, _):
            return RealtimeReadiness(state: .active, diagnostic: "Realtime \(model) active")
        case .failed(_, let message):
            return RealtimeReadiness(state: .failed, diagnostic: message)
        }
    }
}

private actor LiveReloadRace {
    private var result: ReloadResult?
    private var waiters: [CheckedContinuation<ReloadResult, Never>] = []

    func finish(_ result: ReloadResult) {
        guard self.result == nil else { return }
        self.result = result
        waiters.forEach { $0.resume(returning: result) }
        waiters.removeAll()
    }

    func value() async -> ReloadResult {
        if let result {
            return result
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

public enum BottomTab: String, CaseIterable, Identifiable, Sendable {
    case active = "Active"
    case threads = "Threads"
    case talk = "Talk"
    case settings = "Settings"

    public static let primaryDemoTabs: [BottomTab] = [.active, .threads, .talk]

    public var id: String { rawValue }
}

public enum SettingsStatus: Equatable {
    case saved(String)
    case needsAttention(String)
    case failed(String)

    public var message: String {
        switch self {
        case .saved(let message), .needsAttention(let message), .failed(let message):
            return message
        }
    }
}

public struct SourceDiagnostics: Equatable {
    public var sourceLabel: String
    public var sourceDetail: String
    public var isLive: Bool
    public var notes: [String]

    public init(activeThread: ThreadSnapshot, probe: CapabilityProbe) {
        self.isLive = activeThread.freshness.source != .fixture && activeThread.freshness.source != .unavailable
        self.sourceLabel = isLive ? "Live source" : "Fixture source"
        self.sourceDetail = "\(activeThread.freshness.source.rawValue) via \(probe.transport)"
        self.notes = activeThread.freshness.note.map { [$0] } ?? []
        self.notes.append(contentsOf: probe.notes)
        if probe.supportedMethods.isEmpty {
            self.notes.append("No live app-server methods reported")
        } else {
            self.notes.append("\(probe.supportedMethods.count) app-server methods reported")
        }
    }

    public func demoLabel(stale: Bool) -> String {
        if stale {
            return "Refresh"
        }
        return isLive ? "Live" : "Demo"
    }
}

public enum ThreadGroupKind: String, CaseIterable, Identifiable {
    case needsAttention = "Needs Attention"
    case running = "Running"
    case idle = "Idle"
    case completed = "Completed"
    case stale = "Stale"

    public var id: String { rawValue }

    init(thread: ThreadSnapshot) {
        if thread.freshness.isStale {
            self = .stale
        } else {
            switch thread.status {
            case .waitingForApproval, .blocked, .failed:
                self = .needsAttention
            case .running:
                self = .running
            case .completed:
                self = .completed
            default:
                self = .idle
            }
        }
    }
}

public struct ThreadGroup: Identifiable, Equatable {
    public var kind: ThreadGroupKind
    public var threads: [ThreadSnapshot]

    public var id: ThreadGroupKind { kind }
}
