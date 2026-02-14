import SwiftUI

struct ContentView: View {
    @ObservedObject var cloudKit = CloudKitManager.shared
    @ObservedObject var feedManager = FeedManager.shared

    @State private var selectedSidebarItem: SidebarItem? = .allArticles
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var selectedArticle: Article?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedItem: $selectedSidebarItem)
        } content: {
            articleList(for: selectedSidebarItem ?? .allArticles)
                .navigationDestination(item: $selectedArticle) { article in
                    ArticleDetailView(article: article)
                }
        } detail: {
            VStack(spacing: 16) {
                Image(systemName: "newspaper")
                    .font(.system(size: 56))
                    .foregroundStyle(.quaternary)
                Text("Select an article to read")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: selectedSidebarItem) { _, _ in
            selectedArticle = nil
        }
    }

    @ViewBuilder
    private func articleList(for item: SidebarItem) -> some View {
        switch item {
        case .allArticles:
            ArticleListView(title: "All Articles", articles: feedManager.allArticles, selectedArticle: $selectedArticle)
        case .unread:
            ArticleListView(title: "Unread", articles: feedManager.unreadArticles, selectedArticle: $selectedArticle)
        case .starred:
            ArticleListView(title: "Starred", articles: feedManager.starredArticles, selectedArticle: $selectedArticle)
        case .folder(let folder):
            ArticleListView(title: folder.name, articles: feedManager.articlesInFolder(folder.id), selectedArticle: $selectedArticle)
        case .feed(let feed):
            ArticleListView(title: feed.title, articles: feedManager.articles(for: feed.id), selectedArticle: $selectedArticle)
        }
    }
}

// MARK: - iPhone Layout (stack-based navigation)

struct CompactContentView: View {
    @ObservedObject var feedManager = FeedManager.shared

    @State private var selectedArticle: Article?

    var body: some View {
        NavigationStack {
            SidebarView()
                .navigationDestination(for: SidebarItem.self) { item in
                    articleList(for: item)
                        .navigationDestination(item: $selectedArticle) { article in
                            ArticleDetailView(article: article)
                        }
                }
        }
    }

    @ViewBuilder
    private func articleList(for item: SidebarItem) -> some View {
        switch item {
        case .allArticles:
            ArticleListView(title: "All Articles", articles: feedManager.allArticles, selectedArticle: $selectedArticle)
        case .unread:
            ArticleListView(title: "Unread", articles: feedManager.unreadArticles, selectedArticle: $selectedArticle)
        case .starred:
            ArticleListView(title: "Starred", articles: feedManager.starredArticles, selectedArticle: $selectedArticle)
        case .folder(let folder):
            ArticleListView(title: folder.name, articles: feedManager.articlesInFolder(folder.id), selectedArticle: $selectedArticle)
        case .feed(let feed):
            ArticleListView(title: feed.title, articles: feedManager.articles(for: feed.id), selectedArticle: $selectedArticle)
        }
    }
}

#Preview("iPad Split View") {
    ContentView()
}

#Preview("iPhone Stack View") {
    CompactContentView()
}
