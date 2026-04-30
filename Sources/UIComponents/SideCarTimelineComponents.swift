import AppCore
import SwiftUI

struct ToolTimelineCard: View {
    var presentation: SideCarThreadPresentation
    var items: [TimelineItem]
    @Binding var zoom: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Tools and timeline")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Spacer()
                if presentation.timelineSummary.totalCount > 0 {
                    Text("\(presentation.timelineSummary.totalCount) events")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(CodexTheme.secondaryText)
                }
            }

            if !presentation.timelineSummary.buckets.isEmpty {
                FlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(presentation.timelineSummary.buckets) { bucket in
                        Text("\(bucket.kind.rawValue) \(bucket.count)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(CodexTheme.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(CodexTheme.controlBackground, in: Capsule())
                    }
                }
            }

            if let latestTitle = presentation.timelineSummary.latestTitle {
                Text(latestTitle)
                    .font(.system(size: 12))
                    .foregroundStyle(CodexTheme.primaryText)
                    .lineLimit(1)
            }

            HStack {
                Text("Detail")
                    .font(.system(size: 11))
                    .foregroundStyle(CodexTheme.secondaryText)
                Slider(value: $zoom, in: 0...1)
                    .frame(width: 120)
            }

            if items.isEmpty {
                Text("No current turn timeline.")
                    .font(.system(size: 12))
                    .foregroundStyle(CodexTheme.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items) { item in
                        TimelineRow(item: item, zoom: zoom)
                    }
                }
            }
        }
        .padding(14)
        .background(CodexTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct TimelineRow: View {
    var item: TimelineItem
    var zoom: Double

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CodexTheme.primaryText)
                    .lineLimit(1)
                Text(item.summary)
                    .font(.system(size: zoom > 0.7 ? 13 : 12))
                    .foregroundStyle(CodexTheme.secondaryText)
                    .lineLimit(zoom > 0.6 ? 3 : 2)
                if zoom > 0.55, let detail = item.detail {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(CodexTheme.secondaryText.opacity(0.8))
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
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
        case .mcpToolCall, .dynamicToolCall, .collabToolCall, .webSearch, .imageView:
            return "point.3.connected.trianglepath.dotted"
        case .approval:
            return "hand.raised"
        case .contextCompaction:
            return "rectangle.compress.vertical"
        case .userMessage, .agentMessage:
            return "text.bubble"
        case .status, .unknown:
            return "circle.grid.cross"
        }
    }

    private var statusColor: Color {
        switch item.kind {
        case .approval:
            return CodexTheme.accent
        case .fileChange:
            return CodexTheme.statusGreen
        default:
            return CodexTheme.secondaryText
        }
    }
}

private struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + horizontalSpacing
        }

        return CGSize(width: maxWidth.isFinite ? maxWidth : currentX, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            currentX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
