import SwiftUI

/// The main window frame: a native sidebar and a black detail area.
/// Size limits are constant so swapping pages never changes the window's constraints.
public struct MainShell<Detail: View>: View {
    @Binding var selection: Page
    let inboxCount: Int
    let detail: (Page) -> Detail

    public init(selection: Binding<Page>, inboxCount: Int, @ViewBuilder detail: @escaping (Page) -> Detail) {
        _selection = selection
        self.inboxCount = inboxCount
        self.detail = detail
    }

    public var body: some View {
        NavigationSplitView {
            List(Page.allCases, selection: Binding(get: { selection }, set: { if let page = $0 { selection = page } })) { page in
                Label(page.title, systemImage: page.symbol)
                    .badge(page == .inbox ? inboxCount : 0)
                    .tag(page)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            detail(selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Theme.background)
                .navigationTitle(selection.title)
        }
    }
}

/// Shared page layout: a title row with trailing actions, then content.
public struct PageScaffold<Actions: View, Content: View>: View {
    let actions: Actions
    let content: Content

    public init(@ViewBuilder actions: () -> Actions, @ViewBuilder content: () -> Content) {
        self.actions = actions()
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Spacer()
                actions
            }
            content
        }
        .padding(20)
    }
}
