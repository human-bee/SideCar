import AppCore
import SwiftUI

struct SideCarHeaderView: View {
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
                    .truncationMode(.tail)
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
        case .completed, .idle, .unknown:
            return CodexTheme.secondaryText
        }
    }
}

struct ActiveThreadCard: View {
    var thread: ThreadSnapshot
    var diagnostics: SourceDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(thread.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CodexTheme.primaryText)
                        .lineLimit(1)
                    Text(thread.summary)
                        .font(.system(size: 13))
                        .foregroundStyle(CodexTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(thread.status.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(CodexTheme.primaryText)
                    if let model = thread.model {
                        Text(model)
                            .font(.system(size: 11))
                            .foregroundStyle(CodexTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
            }

            HStack(spacing: 8) {
                SourcePill(diagnostics: diagnostics, stale: thread.freshness.isStale)
                if let cwd = thread.cwd {
                    Label(cwd, systemImage: "folder")
                        .font(.system(size: 11))
                        .foregroundStyle(CodexTheme.secondaryText)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(CodexTheme.controlBackground, in: Capsule())
                }
            }
        }
        .padding(14)
        .background(CodexTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct LiveContextCard: View {
    var presentation: SideCarThreadPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(presentation.liveContext.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Spacer()
                Text(presentation.liveContext.badgeText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CodexTheme.secondaryText)
            }

            Text(presentation.liveContext.detail)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(CodexTheme.secondaryText)
                .lineLimit(1)

            ProgressView(value: presentation.liveContext.progressValue) {
                Text(presentation.liveContext.progressLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CodexTheme.primaryText)
            }
            .progressViewStyle(.linear)

            if let note = presentation.liveContext.note {
                Text(note)
                    .font(.system(size: 11))
                    .foregroundStyle(CodexTheme.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(CodexTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct SourcePill: View {
    var diagnostics: SourceDiagnostics
    var stale: Bool

    var body: some View {
        Label(stale ? "\(diagnostics.sourceLabel) stale" : diagnostics.sourceLabel, systemImage: diagnostics.isLive ? "dot.radiowaves.left.and.right" : "shippingbox")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(diagnostics.isLive ? CodexTheme.statusGreen : CodexTheme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(CodexTheme.controlBackground, in: Capsule())
            .lineLimit(1)
    }
}

struct CodexDivider: View {
    var body: some View {
        Rectangle()
            .fill(CodexTheme.divider)
            .frame(height: 1)
    }
}
