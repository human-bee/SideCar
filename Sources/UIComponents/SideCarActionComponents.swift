import AppCore
import SwiftUI

struct VoiceAndQueueCard: View {
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Label("Talk with SideCar", systemImage: "bubble.left.and.text.bubble.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Spacer()
                Toggle("speech-to-speech", isOn: $viewModel.speechToSpeechEnabled)
                    .font(.system(size: 11))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .help("Enable speech-to-speech mode when the live audio loop is available.")
            }

            TextField("Ask about this Codex run...", text: $viewModel.chatDraft)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Button("/side") {
                    viewModel.stageSideQuestion()
                }
                .buttonStyle(.bordered)
                .help("Ask a tangent question in a guarded side conversation.")

                Button("Queue") {
                    viewModel.stageMessage(asSteer: false)
                }
                .buttonStyle(.borderedProminent)

                Button("Steer") {
                    viewModel.stageMessage(asSteer: true)
                }
                .buttonStyle(.bordered)

                Spacer()
                Label(viewModel.realtimeReadiness.diagnostic, systemImage: "waveform")
                    .font(.system(size: 11))
                    .foregroundStyle(CodexTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .background(CodexTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ApprovalAndActionCard: View {
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Queue, safe gate, actions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Spacer()
                if viewModel.isReloading {
                    Text("Refreshing")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CodexTheme.secondaryText)
                }
            }

            ActionStripView(viewModel: viewModel)

            if let approvalCenter = viewModel.pendingApprovalCenter {
                ApprovalCenterView(approvalCenter: approvalCenter, viewModel: viewModel)
            }

            RecommendationsView(recommendations: viewModel.activeThread.recommendations)

            if let action = viewModel.stagedAction {
                StagedActionCard(
                    action: action,
                    onConfirm: viewModel.confirmStagedAction,
                    onDismiss: viewModel.dismissStagedAction
                )
            }
        }
        .padding(14)
        .background(CodexTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ApprovalCenterView: View {
    var approvalCenter: PendingApprovalCenter
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Approval center", systemImage: "hand.raised")
                    .font(.system(size: 12, weight: .semibold))
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
            ForEach(approvalCenter.items) { item in
                ApprovalRow(item: item) { approved in
                    viewModel.stageApprovalDecision(approved: approved, itemID: item.id)
                }
            }
        }
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
                    .lineLimit(1)
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

private struct RecommendationsView: View {
    var recommendations: [String]

    var body: some View {
        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested next")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                ForEach(recommendations, id: \.self) { recommendation in
                    Label(recommendation, systemImage: "arrow.turn.down.right")
                        .font(.system(size: 12))
                        .foregroundStyle(CodexTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct ActionStripView: View {
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        HStack(spacing: 8) {
            actionButton("/side", "sidebar.right", .sideQuestion)
            actionButton("Steer", "arrow.triangle.turn.up.right.circle", .steerTurn)
            actionButton("Fork", "arrow.triangle.branch", .forkThread)
            actionButton("Interrupt", "stop.circle", .interruptTurn)
            actionButton("Review", "checklist", .startReview)
            actionButton("Compact", "rectangle.compress.vertical", .compactThread)
            Spacer()
            Button(viewModel.isReloading ? "Refreshing" : "Refresh") {
                viewModel.reloadFromBestAvailableSource()
            }
            .disabled(viewModel.isReloading)
            .font(.system(size: 12))
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
                .lineLimit(8)
                .fixedSize(horizontal: false, vertical: true)
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
