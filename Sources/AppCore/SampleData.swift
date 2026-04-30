import Foundation

public enum SampleData {
    public static let activeThread = ThreadSnapshot(
        id: "019dd7bf-4e60-78d0-bb1a-0817b43612ad",
        title: "Prototype Codex sidebar agent",
        cwd: "~/Documents/Codex/SideCar",
        status: .running,
        model: "gpt-5.5",
        freshness: Freshness(source: .fixture, note: "Fixture mode until app-server is connected."),
        currentTurn: TurnSnapshot(
            id: "turn-fixture-001",
            phase: .running,
            startedAt: Date().addingTimeInterval(-900),
            itemGroups: [
                TimelineItem(kind: .plan, title: "Plan", summary: "Scaffold native SideCar app, core contracts, adapters, docs, and tests.", source: .fixture),
                TimelineItem(kind: .commandExecution, title: "Tooling", summary: "Verified SwiftPM and macOS build toolchain.", detail: "No repo files existed, so SideCar starts as a clean package-first project.", source: .fixture),
                TimelineItem(kind: .reasoningSummary, title: "Reasoning Summary", summary: "App-server is authoritative; Codex++ is optional active-window context.", source: .fixture),
                TimelineItem(kind: .fileChange, title: "Files", summary: "Creating package modules and docs for MVP behavior.", source: .fixture)
            ],
            blockers: []
        ),
        summary: "A long-running Codex session is building the SideCar MVP scaffold. The current useful state is implementation progress, not a final answer.",
        recommendations: [
            "Keep app-server as the live source of truth.",
            "Stage actions with target-card confirmation.",
            "Use fixture mode for UI and regression tests before live app-server streaming is complete."
        ]
    )

    public static let backgroundThreads = [
        ThreadSnapshot(
            id: "thread-background-001",
            title: "Review payout reconciliation plan",
            cwd: "~/audio-view-tracker-pro",
            status: .waitingForApproval,
            model: "gpt-5.5",
            freshness: Freshness(source: .fixture, isStale: false),
            currentTurn: TurnSnapshot(id: "turn-background-001", phase: .waitingForApproval),
            summary: "Waiting for a command approval.",
            recommendations: ["Open approval card before the turn stalls."]
        ),
        ThreadSnapshot(
            id: "thread-background-002",
            title: "TP website production comparison",
            cwd: "~/TP-website",
            status: .completed,
            model: "gpt-5.4",
            freshness: Freshness(source: .fixture, isStale: true, note: "Completed earlier in fixture mode."),
            currentTurn: TurnSnapshot(id: "turn-background-002", phase: .completed),
            summary: "Comparison run completed.",
            recommendations: ["Read final summary before resuming."]
        )
    ]
}
