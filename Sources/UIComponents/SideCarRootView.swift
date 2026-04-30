import SwiftUI

public struct SideCarRootView: View {
    @ObservedObject private var viewModel: SideCarViewModel

    public init(viewModel: SideCarViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let presentation = SideCarThreadPresentation(
            thread: viewModel.activeThread,
            diagnostics: viewModel.sourceDiagnostics
        )

        VStack(spacing: 0) {
            SideCarHeaderView(
                thread: viewModel.activeThread,
                diagnostics: viewModel.sourceDiagnostics
            )
            CodexDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ActiveThreadCard(thread: viewModel.activeThread, diagnostics: viewModel.sourceDiagnostics)
                    LiveContextCard(presentation: presentation)
                    ToolTimelineCard(
                        presentation: presentation,
                        items: viewModel.activeThread.currentTurn?.itemGroups ?? [],
                        zoom: $viewModel.timelineZoom
                    )
                    VoiceAndQueueCard(viewModel: viewModel)
                    ApprovalAndActionCard(viewModel: viewModel)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            CodexDivider()
            BottomDockView(viewModel: viewModel)
        }
        .frame(minWidth: 430, idealWidth: 500, minHeight: 640, idealHeight: 760)
        .background(CodexTheme.contentBackground)
        .tint(CodexTheme.accent)
    }
}
