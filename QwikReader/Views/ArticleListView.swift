import SwiftUI

struct ArticleListView: View {
    let title: String
    let articles: [Article]

    @ObservedObject var feedManager = FeedManager.shared
    @ObservedObject var cloudKit = CloudKitManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var offlineManager = OfflineManager.shared

    @State private var searchText = ""
    @State private var selectedArticle: Article?

    private var filteredArticles: [Article] {
        if searchText.isEmpty {
            return articles
        }
        return articles.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.author?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.summary?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        Group {
            if filteredArticles.isEmpty {
                emptyState
            } else {
                articleContent
            }
        }
        .navigationTitle(title)
        .searchable(text: $searchText, prompt: "Search articles")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                layoutPicker
                moreMenu
            }
        }
        .refreshable {
            await feedManager.refreshAllFeeds()
        }
    }

    @ViewBuilder
    private var articleContent: some View {
        switch themeManager.articleListLayout {
        case .magazine:
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(filteredArticles) { article in
                        NavigationLink(value: article) {
                            ArticleRowView(
                                article: article,
                                feedTitle: feedTitle(for: article),
                                layout: .magazine
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu { articleContextMenu(article) }
                    }
                }
                .padding(.horizontal)
            }
        default:
            List(filteredArticles) { article in
                NavigationLink(value: article) {
                    ArticleRowView(
                        article: article,
                        feedTitle: feedTitle(for: article),
                        layout: themeManager.articleListLayout
                    )
                }
                .swipeActions(edge: .leading) {
                    Button {
                        feedManager.toggleStarred(article)
                    } label: {
                        Image(systemName: article.isStarred ? "star.slash" : "star.fill")
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        feedManager.markAsRead(article)
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .tint(.blue)

                    Button {
                        Task {
                            let updated = await offlineManager.downloadArticle(article)
                            if let index = feedManager.articles[article.feedID]?.firstIndex(where: { $0.id == article.id }) {
                                feedManager.articles[article.feedID]?[index] = updated
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.down.circle")
                    }
                    .tint(.green)
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Articles")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Pull to refresh or add a new feed to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var layoutPicker: some View {
        Menu {
            ForEach(ArticleListLayout.allCases, id: \.self) { layout in
                Button {
                    withAnimation { themeManager.articleListLayout = layout }
                } label: {
                    Label(layout.displayName, systemImage: layout.icon)
                }
            }
        } label: {
            Image(systemName: themeManager.articleListLayout.icon)
        }
    }

    private var moreMenu: some View {
        Menu {
            Button {
                feedManager.markAllAsRead()
            } label: {
                Label("Mark All as Read", systemImage: "checkmark.circle")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    @ViewBuilder
    private func articleContextMenu(_ article: Article) -> some View {
        Button {
            feedManager.toggleStarred(article)
        } label: {
            Label(
                article.isStarred ? "Unstar" : "Star",
                systemImage: article.isStarred ? "star.slash" : "star"
            )
        }

        Button {
            feedManager.markAsRead(article)
        } label: {
            Label("Mark as Read", systemImage: "checkmark")
        }

        Button {
            Task {
                let updated = await offlineManager.downloadArticle(article)
                if let index = feedManager.articles[article.feedID]?.firstIndex(where: { $0.id == article.id }) {
                    feedManager.articles[article.feedID]?[index] = updated
                }
            }
        } label: {
            Label("Download for Offline", systemImage: "arrow.down.circle")
        }

        if let url = article.url {
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    private func feedTitle(for article: Article) -> String? {
        cloudKit.feeds.first(where: { $0.id == article.feedID })?.title
    }
}
