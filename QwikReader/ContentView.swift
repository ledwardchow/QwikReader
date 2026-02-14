import SwiftUI

struct ContentView: View {
    @ObservedObject var cloudKit = CloudKitManager.shared
    @ObservedObject var feedManager = FeedManager.shared

    @State private var selectedSidebarItem: SidebarItem? = .allArticles
    @State private var selectedArticle: Article?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } content: {
            Group {
                if let item = selectedSidebarItem {
                    articleList(for: item)
                } else {
                    ArticleListView(title: "All Articles", articles: feedManager.allArticles)
                }
            }
            .navigationDestination(for: Article.self) { article in
                ArticleDetailView(article: article)
            }
        } detail: {
            if let article = selectedArticle {
                ArticleDetailView(article: article)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 56))
                        .foregroundStyle(.quaternary)
                    Text("Select an article to read")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func articleList(for item: SidebarItem) -> some View {
        switch item {
        case .allArticles:
            ArticleListView(title: "All Articles", articles: feedManager.allArticles)
        case .unread:
            ArticleListView(title: "Unread", articles: feedManager.unreadArticles)
        case .starred:
            ArticleListView(title: "Starred", articles: feedManager.starredArticles)
        case .folder(let folder):
            ArticleListView(title: folder.name, articles: feedManager.articlesInFolder(folder.id))
        case .feed(let feed):
            ArticleListView(title: feed.title, articles: feedManager.articles(for: feed.id))
        }
    }
}

// MARK: - iPhone Layout (stack-based navigation)

struct CompactContentView: View {
    @ObservedObject var feedManager = FeedManager.shared

    var body: some View {
        NavigationStack {
            SidebarView()
                .navigationDestination(for: SidebarItem.self) { item in
                    articleList(for: item)
                        .navigationDestination(for: Article.self) { article in
                            ArticleDetailView(article: article)
                        }
                }
        }
    }

    @ViewBuilder
    private func articleList(for item: SidebarItem) -> some View {
        switch item {
        case .allArticles:
            ArticleListView(title: "All Articles", articles: feedManager.allArticles)
        case .unread:
            ArticleListView(title: "Unread", articles: feedManager.unreadArticles)
        case .starred:
            ArticleListView(title: "Starred", articles: feedManager.starredArticles)
        case .folder(let folder):
            ArticleListView(title: folder.name, articles: feedManager.articlesInFolder(folder.id))
        case .feed(let feed):
            ArticleListView(title: feed.title, articles: feedManager.articles(for: feed.id))
        }
    }
}
