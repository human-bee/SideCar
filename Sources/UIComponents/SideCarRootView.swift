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
            SideCarHeaderView(viewModel: viewModel)
            CodexDivider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch viewModel.selectedBottomTab {
                    case .active:
                        ActiveThreadCard(thread: viewModel.activeThread, diagnostics: viewModel.sourceDiagnostics)
                        LiveContextCard(presentation: presentation)
                        ToolTimelineCard(
                            presentation: presentation,
                            items: viewModel.activeThread.currentTurn?.itemGroups ?? [],
                            zoom: $viewModel.timelineZoom
                        )
                        VoiceAndQueueCard(viewModel: viewModel)
                        ApprovalAndActionCard(viewModel: viewModel)
                    case .threads:
                        ThreadsDock(viewModel: viewModel)
                    case .talk:
                        TalkDock(viewModel: viewModel)
                        ApprovalAndActionCard(viewModel: viewModel)
                    case .settings:
                        SettingsDock(viewModel: viewModel)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 430, idealWidth: 500, minHeight: 560, idealHeight: 660)
        .background(CodexTheme.contentBackground)
        .tint(CodexTheme.accent)
    }
}
