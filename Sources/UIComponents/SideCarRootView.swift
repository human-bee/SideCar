import AppCore
import SwiftUI
import VoiceCore

public struct SideCarRootView: View {
    @ObservedObject private var viewModel: SideCarViewModel

    public init(viewModel: SideCarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HeaderView(thread: viewModel.activeThread, diagnostics: viewModel.sourceDiagnostics)
            CodexDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SourceDiagnosticsView(diagnostics: viewModel.sourceDiagnostics)
                    StatusSummaryView(thread: viewModel.activeThread)
                    if let approvalCenter = viewModel.pendingApprovalCenter {
                        ApprovalCenterView(approvalCenter: approvalCenter, viewModel: viewModel)
                    }
                    TimelineMapView(
                        items: viewModel.activeThread.currentTurn?.itemGroups ?? [],
                        zoom: $viewModel.timelineZoom
                    )
                    RecommendationsView(recommendations: viewModel.activeThread.recommendations)
                    ActionStripView(viewModel: viewModel)
                    if let action = viewModel.stagedAction {
                        StagedActionCard(action: action, onConfirm: viewModel.confirmStagedAction, onDismiss: viewModel.dismissStagedAction)
                    }
                }
                .padding(18)
            }
            CodexDivider()
            BottomDockView(viewModel: viewModel)
        }
        .frame(minWidth: 430, idealWidth: 500, minHeight: 640, idealHeight: 760)
        .background(CodexTheme.contentBackground)
        .tint(CodexTheme.accent)
    }
}

private struct ApprovalCenterView: View {
    var approvalCenter: PendingApprovalCenter
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Approval Center", systemImage: "hand.raised")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Spacer()
                Text("\(approvalCenter.count) pending")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CodexTheme.secondaryText)
            }
            Text("thread \(approvalCenter.scope.threadId) • turn \(approvalCenter.scope.turnId)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CodexTheme.secondaryText)
                .lineLimit(1)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(approvalCenter.items) { item in
                    ApprovalRow(item: item) { approved in
                        viewModel.stageApprovalDecision(approved: approved, itemID: item.id)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ApprovalRow: View {
    var item: TimelineItem
    var onDecision: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Text(item.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(CodexTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
            HStack(spacing: 6) {
                Button("Decline") {
                    onDecision(false)
                }
                .buttonStyle(.borderless)

                Button("Accept") {
                    onDecision(true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct HeaderView: View {
    var thread: ThreadSnapshot
    var diagnostics: SourceDiagnostics

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text("SideCar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Text(thread.title)
                    .font(.system(size: 12))
                    .foregroundStyle(CodexTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            SourcePill(diagnostics: diagnostics, stale: thread.freshness.isStale)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CodexTheme.contentBackground)
    }

    private var statusColor: Color {
        switch thread.status {
        case .running:
            return CodexTheme.statusGreen
        case .waitingForApproval, .blocked:
            return CodexTheme.accent
        case .failed:
            return .red
        case .completed:
            return CodexTheme.secondaryText
        default:
            return CodexTheme.secondaryText
        }
    }
}

private struct SourcePill: View {
    var diagnostics: SourceDiagnostics
    var stale: Bool

    var body: some View {
        Label(stale ? "\(diagnostics.sourceLabel) stale" : diagnostics.sourceLabel, systemImage: diagnostics.isLive ? "dot.radiowaves.left.and.right" : "shippingbox")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(diagnostics.isLive ? CodexTheme.statusGreen : CodexTheme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(CodexTheme.controlBackground, in: Capsule())
    }
}

private struct SourceDiagnosticsView: View {
    var diagnostics: SourceDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(diagnostics.sourceLabel, systemImage: diagnostics.isLive ? "antenna.radiowaves.left.and.right" : "doc.text.magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(diagnostics.isLive ? CodexTheme.statusGreen : CodexTheme.primaryText)
                Spacer()
                Text(diagnostics.sourceDetail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CodexTheme.secondaryText)
                    .lineLimit(1)
            }
            ForEach(diagnostics.notes.prefix(3), id: \.self) { note in
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(CodexTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(CodexTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StatusSummaryView: View {
    var thread: ThreadSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(thread.status.rawValue, systemImage: "waveform.path.ecg")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Spacer()
                if let model = thread.model {
                    Text(model)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CodexTheme.secondaryText)
                }
            }
            Text(thread.summary)
                .font(.system(size: 14))
                .foregroundStyle(CodexTheme.primaryText)
                .lineSpacing(3)
            if let cwd = thread.cwd {
                Text(cwd)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CodexTheme.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

private struct TimelineMapView: View {
    var items: [TimelineItem]
    @Binding var zoom: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Timeline Map")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Spacer()
                Slider(value: $zoom, in: 0...1)
                    .frame(width: 130)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    TimelineRow(item: item, zoom: zoom)
                }
            }
        }
    }
}

private struct TimelineRow: View {
    var item: TimelineItem
    var zoom: Double

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CodexTheme.primaryText)
                .frame(width: 22, height: 22)
                .background(CodexTheme.controlBackground, in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Text(item.summary)
                    .font(.system(size: zoom > 0.7 ? 13 : 12))
                    .foregroundStyle(CodexTheme.secondaryText)
                if zoom > 0.55, let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(CodexTheme.secondaryText.opacity(0.75))
                }
            }
        }
        .padding(10)
        .background(CodexTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var iconName: String {
        switch item.kind {
        case .plan:
            return "list.bullet.rectangle"
        case .commandExecution:
            return "terminal"
        case .fileChange:
            return "doc.badge.gearshape"
        case .reasoningSummary:
            return "brain.head.profile"
        case .mcpToolCall, .dynamicToolCall, .collabToolCall:
            return "point.3.connected.trianglepath.dotted"
        case .approval:
            return "hand.raised"
        default:
            return "circle.grid.cross"
        }
    }
}

private struct RecommendationsView: View {
    var recommendations: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended Next")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CodexTheme.primaryText)
            ForEach(recommendations, id: \.self) { recommendation in
                Label(recommendation, systemImage: "arrow.turn.down.right")
                    .font(.system(size: 12))
                    .foregroundStyle(CodexTheme.secondaryText)
            }
        }
    }
}

private struct ActionStripView: View {
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        HStack(spacing: 8) {
            actionButton("Steer", "arrow.triangle.turn.up.right.circle", .steerTurn)
            actionButton("Fork", "arrow.triangle.branch", .forkThread)
            actionButton("Interrupt", "stop.circle", .interruptTurn)
            actionButton("Review", "checklist", .startReview)
            actionButton("Compact", "rectangle.compress.vertical", .compactThread)
        }
        .foregroundStyle(CodexTheme.secondaryText)
    }

    private func actionButton(_ title: String, _ icon: String, _ kind: SideCarActionKind) -> some View {
        Button {
            viewModel.stage(kind)
        } label: {
            Label(title, systemImage: icon)
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

private struct StagedActionCard: View {
    var action: SideCarAction
    var onConfirm: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(action.kind.rawValue, systemImage: "checkmark.shield")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Spacer()
                Text(action.confirmationState.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CodexTheme.secondaryText)
            }
            Text(action.targetThreadId)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CodexTheme.secondaryText)
                .lineLimit(1)
            if let targetTurnId = action.targetTurnId {
                Text(targetTurnId)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CodexTheme.secondaryText)
                    .lineLimit(1)
            }
            Text(action.payloadPreview)
                .font(.system(size: 12))
                .foregroundStyle(CodexTheme.primaryText)
                .lineSpacing(2)
            HStack {
                Button("Dismiss", action: onDismiss)
                Spacer()
                if action.kind == .approvalDecision {
                    Text("Draft only")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CodexTheme.secondaryText)
                } else {
                    Button("Confirm", action: onConfirm)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(12)
        .background(CodexTheme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct BottomDockView: View {
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        VStack(spacing: 0) {
            CodexTabBar(selection: $viewModel.selectedBottomTab)
                .padding(12)
            Group {
                switch viewModel.selectedBottomTab {
                case .active:
                    ActiveDock(viewModel: viewModel)
                case .threads:
                    ThreadsDock(viewModel: viewModel)
                case .talk:
                    TalkDock(viewModel: viewModel)
                case .settings:
                    SettingsDock(viewModel: viewModel)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(CodexTheme.panelBackground)
    }
}

private struct CodexTabBar: View {
    @Binding var selection: BottomTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BottomTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: selection == tab ? .semibold : .medium))
                        .frame(minWidth: 88)
                        .padding(.vertical, 7)
                        .foregroundStyle(selection == tab ? Color.white : CodexTheme.primaryText)
                        .background(selection == tab ? CodexTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(CodexTheme.controlBackground, in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct ActiveDock: View {
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        HStack {
            Label("Queue by default. Say steer explicitly to affect the running turn.", systemImage: "text.bubble")
                .font(.system(size: 12))
                .foregroundStyle(CodexTheme.secondaryText)
            Spacer()
            Button(viewModel.isReloading ? "Refreshing" : "Refresh") {
                viewModel.reloadFromBestAvailableSource()
            }
            .disabled(viewModel.isReloading)
        }
    }
}

private struct ThreadsDock: View {
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(viewModel.groupedThreads) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(group.kind.rawValue) (\(group.threads.count))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(CodexTheme.secondaryText)
                        ForEach(group.threads) { thread in
                            Button {
                                viewModel.selectThread(thread.id)
                            } label: {
                                ThreadSwitchboardRow(thread: thread, isSelected: viewModel.selectedThreadId == thread.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 210)
    }
}

private struct ThreadSwitchboardRow: View {
    var thread: ThreadSnapshot
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(CodexTheme.primaryText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(thread.cwd ?? "No cwd")
                    Text(thread.freshness.source.rawValue)
                }
                .font(.system(size: 10))
                .foregroundStyle(CodexTheme.secondaryText)
                .lineLimit(1)
            }
            Spacer()
            Text(thread.status.rawValue)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(CodexTheme.secondaryText)
        }
        .padding(8)
        .background(isSelected ? CodexTheme.accent.opacity(0.16) : CodexTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusColor: Color {
        switch thread.status {
        case .running:
            return CodexTheme.statusGreen
        case .waitingForApproval, .blocked:
            return CodexTheme.accent
        case .failed:
            return .red
        default:
            return CodexTheme.secondaryText
        }
    }
}

private struct TalkDock: View {
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Ask SideCar. Queues follow-up unless you explicitly steer.", text: $viewModel.chatDraft)
                    .textFieldStyle(.roundedBorder)
                Button {
                    viewModel.stageMessage(asSteer: false)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                }
                .help("Stage queued follow-up")
            }
            HStack {
                Toggle("speech-to-speech", isOn: $viewModel.speechToSpeechEnabled)
                    .font(.system(size: 12))
                Spacer()
                Button("Request Screen Access") {
                    viewModel.requestScreenCapturePermission()
                }
                .font(.system(size: 12))
                Text(viewModel.screenPermission.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(CodexTheme.secondaryText)
            }
        }
    }
}

public struct SideCarSettingsView: View {
    @ObservedObject private var viewModel: SideCarViewModel

    public init(viewModel: SideCarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(CodexTheme.primaryText)
            SettingsDock(viewModel: viewModel)
            Spacer()
        }
        .padding(20)
        .frame(width: 420, height: 260)
        .background(CodexTheme.contentBackground)
        .tint(CodexTheme.accent)
    }
}

private struct SettingsDock: View {
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("OpenAI API Key")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                SecureField("sk-...", text: $viewModel.openAIKeyDraft)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Label(viewModel.openAIKeyStatus.message, systemImage: statusIcon)
                        .font(.system(size: 11))
                        .foregroundStyle(statusColor)
                    Spacer()
                    Button("Save Key") {
                        viewModel.saveOpenAIKeyDraft()
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Global Hotkey")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Label("Scaffolded: Option-Space toggles SideCar while the app is active.", systemImage: "keyboard")
                    .font(.system(size: 11))
                    .foregroundStyle(CodexTheme.secondaryText)
            }
        }
    }

    private var statusIcon: String {
        switch viewModel.openAIKeyStatus {
        case .saved:
            return "checkmark.seal"
        case .needsAttention:
            return "exclamationmark.circle"
        case .failed:
            return "xmark.octagon"
        }
    }

    private var statusColor: Color {
        switch viewModel.openAIKeyStatus {
        case .saved:
            return CodexTheme.statusGreen
        case .needsAttention:
            return CodexTheme.secondaryText
        case .failed:
            return .red
        }
    }
}

private struct CodexDivider: View {
    var body: some View {
        Rectangle()
            .fill(CodexTheme.divider)
            .frame(height: 1)
    }
}
