import AppCore
import Foundation

public struct SideCarThreadPresentation: Equatable {
    public struct LiveContext: Equatable {
        public var title: String
        public var detail: String
        public var badgeText: String
        public var note: String?
        public var progressLabel: String
        public var progressValue: Double

        public init(title: String, detail: String, badgeText: String, note: String?, progressLabel: String, progressValue: Double) {
            self.title = title
            self.detail = detail
            self.badgeText = badgeText
            self.note = note
            self.progressLabel = progressLabel
            self.progressValue = progressValue
        }
    }

    public struct TimelineSummary: Equatable {
        public struct Bucket: Equatable, Identifiable {
            public enum Kind: String, Equatable {
                case plan = "Plan"
                case tools = "Tools"
                case changes = "Changes"
                case approvals = "Approval"
                case notes = "Notes"
            }

            public var kind: Kind
            public var count: Int

            public init(kind: Kind, count: Int) {
                self.kind = kind
                self.count = count
            }

            public var id: Kind { kind }
        }

        public var totalCount: Int
        public var buckets: [Bucket]
        public var latestTitle: String?

        public init(totalCount: Int, buckets: [Bucket], latestTitle: String?) {
            self.totalCount = totalCount
            self.buckets = buckets
            self.latestTitle = latestTitle
        }
    }

    public var liveContext: LiveContext
    public var timelineSummary: TimelineSummary

    public init(thread: ThreadSnapshot, diagnostics: SourceDiagnostics) {
        let note = thread.freshness.note ?? diagnostics.notes.first
        self.liveContext = LiveContext(
            title: Self.contextTitle(for: thread),
            detail: Self.contextDetail(for: thread),
            badgeText: diagnostics.sourceLabel,
            note: note,
            progressLabel: Self.progressLabel(for: thread),
            progressValue: Self.progressValue(for: thread)
        )
        self.timelineSummary = Self.timelineSummary(for: thread)
    }

    private static func contextTitle(for thread: ThreadSnapshot) -> String {
        if thread.freshness.isStale {
            return "Needs refresh"
        }
        switch thread.status {
        case .running:
            return "Live context"
        case .waitingForApproval:
            return "Awaiting approval"
        case .blocked:
            return "Blocked"
        case .completed:
            return "Turn complete"
        case .failed:
            return "Needs intervention"
        case .idle, .unknown:
            return "Standing by"
        }
    }

    private static func contextDetail(for thread: ThreadSnapshot) -> String {
        let source = thread.freshness.source.rawValue
        if let phase = thread.currentTurn?.phase {
            return "\(phase.rawValue) via \(source)"
        }
        return "\(thread.status.rawValue) via \(source)"
    }

    private static func progressLabel(for thread: ThreadSnapshot) -> String {
        let itemCount = thread.currentTurn?.itemGroups.count ?? 0
        let blockerCount = thread.currentTurn?.blockers.count ?? 0
        switch thread.status {
        case .running:
            return "\(max(itemCount, 1)) events in flight"
        case .waitingForApproval:
            return "\(max(blockerCount, 1)) approvals waiting"
        case .blocked:
            return "\(max(blockerCount, 1)) blockers active"
        case .completed:
            return "Turn finished"
        case .failed:
            return "Turn failed"
        case .idle, .unknown:
            return itemCount == 0 ? "No active turn" : "\(itemCount) recent events"
        }
    }

    private static func progressValue(for thread: ThreadSnapshot) -> Double {
        if thread.freshness.isStale {
            return 0.2
        }
        switch thread.status {
        case .running:
            return 0.7
        case .waitingForApproval, .blocked:
            return 0.5
        case .completed:
            return 1
        case .failed:
            return 0.15
        case .idle, .unknown:
            return 0.35
        }
    }

    private static func timelineSummary(for thread: ThreadSnapshot) -> TimelineSummary {
        let items = thread.currentTurn?.itemGroups ?? []
        let counts = Dictionary(grouping: items, by: bucketKind(for:))
            .mapValues(\.count)
        let order: [TimelineSummary.Bucket.Kind] = [.plan, .tools, .changes, .approvals, .notes]
        let buckets: [TimelineSummary.Bucket] = order.compactMap { kind in
            guard let count = counts[kind], count > 0 else { return nil }
            return TimelineSummary.Bucket(kind: kind, count: count)
        }
        return TimelineSummary(
            totalCount: items.count,
            buckets: buckets,
            latestTitle: items.last?.title
        )
    }

    private static func bucketKind(for item: TimelineItem) -> TimelineSummary.Bucket.Kind {
        switch item.kind {
        case .plan:
            return .plan
        case .commandExecution, .mcpToolCall, .dynamicToolCall, .collabToolCall, .webSearch, .imageView:
            return .tools
        case .fileChange, .contextCompaction:
            return .changes
        case .approval:
            return .approvals
        case .reasoningSummary, .status, .userMessage, .agentMessage, .unknown:
            return .notes
        }
    }
}
