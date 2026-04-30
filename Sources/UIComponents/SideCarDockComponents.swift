import AppCore
import Foundation
import SwiftUI

struct BottomDockView: View {
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
                .lineLimit(2)
            Spacer()
            Text(viewModel.capabilityProbe.transport)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CodexTheme.secondaryText)
                .lineLimit(1)
        }
    }
}

private struct ThreadsDock: View {
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(viewModel.groupedThreads)) { group in
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
                .lineLimit(1)
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
        case .completed, .idle, .unknown:
            return CodexTheme.secondaryText
        }
    }
}

private struct TalkDock: View {
    @ObservedObject var viewModel: SideCarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Ask SideCar. Queues follow-up unless you explicitly steer.", text: $viewModel.chatDraft)
                .textFieldStyle(.roundedBorder)
            HStack {
                Toggle("speech-to-speech", isOn: $viewModel.speechToSpeechEnabled)
                    .font(.system(size: 12))
                Spacer()
                Button("Check Realtime") {
                    Task {
                        await viewModel.checkRealtimeReadiness()
                    }
                }
                .font(.system(size: 12))
                Button("Request Screen Access") {
                    viewModel.requestScreenCapturePermission()
                }
                .font(.system(size: 12))
                Text(viewModel.screenPermission.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(CodexTheme.secondaryText)
            }
            Label(viewModel.realtimeReadiness.diagnostic, systemImage: realtimeStatusIcon)
                .font(.system(size: 11))
                .foregroundStyle(realtimeStatusColor)
                .lineLimit(1)
            Text("Preview controls stage screen context only. Live speech-to-speech streaming is not implemented in this slice.")
                .font(.system(size: 11))
                .foregroundStyle(CodexTheme.secondaryText)
                .lineLimit(2)
            HStack(spacing: 8) {
                Button("Capture Preview") {
                    do {
                        try viewModel.capturePreview()
                    } catch {
                        viewModel.clearPreview()
                    }
                }
                .font(.system(size: 12))
                Button("Accept Preview") {
                    viewModel.acceptPreview()
                }
                .font(.system(size: 12))
                .disabled(viewModel.previewBundle == nil)
                Button("Clear Preview") {
                    viewModel.clearPreview()
                }
                .font(.system(size: 12))
                .disabled(viewModel.previewBundle == nil)
            }
            if let preview = viewModel.previewBundle {
                PreviewMetadataView(preview: preview)
            } else {
                Text("No preview captured.")
                    .font(.system(size: 11))
                    .foregroundStyle(CodexTheme.secondaryText)
            }
        }
    }

    private var realtimeStatusIcon: String {
        switch viewModel.realtimeReadiness.state {
        case .missingKey:
            return "key.slash"
        case .ready:
            return "checkmark.circle"
        case .active:
            return "waveform.badge.mic"
        case .failed:
            return "xmark.octagon"
        }
    }

    private var realtimeStatusColor: Color {
        switch viewModel.realtimeReadiness.state {
        case .missingKey:
            return CodexTheme.secondaryText
        case .ready, .active:
            return CodexTheme.statusGreen
        case .failed:
            return .red
        }
    }
}

private struct PreviewMetadataView: View {
    var preview: VisualContextBundle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview: \(preview.displayName)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(CodexTheme.primaryText)
                .lineLimit(1)
            Text("File: \(previewFileName)")
                .font(.system(size: 11))
                .foregroundStyle(CodexTheme.secondaryText)
                .lineLimit(1)
            Text("Accepted: \(preview.previewAccepted ? "yes" : "no") · Sent: \(preview.sentToModel ? "yes" : "no")")
                .font(.system(size: 11))
                .foregroundStyle(CodexTheme.secondaryText)
        }
        .padding(10)
        .background(CodexTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private var previewFileName: String {
        preview.imagePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "none"
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
                    .lineLimit(2)
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
