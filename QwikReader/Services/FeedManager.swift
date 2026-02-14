import Foundation
import Combine

@MainActor
final class FeedManager: ObservableObject {
    static let shared = FeedManager()

    @Published var articles: [UUID: [Article]] = [:]  // feedID -> articles
    @Published var isRefreshing = false

    private let cloudKit = CloudKitManager.shared
    private let offlineManager = OfflineManager.shared
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
        loadCachedArticles()
    }

    var allArticles: [Article] {
        articles.values.flatMap { $0 }.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    }

    var unreadArticles: [Article] {
        allArticles.filter { !$0.isRead }
    }

    var starredArticles: [Article] {
        allArticles.filter { $0.isStarred }
    }

    func articles(for feedID: UUID) -> [Article] {
        (articles[feedID] ?? []).sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    }

    func articlesInFolder(_ folderID: UUID) -> [Article] {
        let feedIDs = Set(cloudKit.feeds.filter { $0.folderID == folderID }.map(\.id))
        return allArticles.filter { feedIDs.contains($0.feedID) }
    }

    // MARK: - Feed Operations

    func addFeed(url: URL) async throws -> Feed {
        let data = try await fetchData(from: url)
        let parser = RSSParser()
        guard let parsed = parser.parse(data: data) else {
            throw FeedError.parseError
        }

        let feed = Feed(
            title: parsed.title.isEmpty ? url.host ?? "Untitled" : parsed.title,
            url: url,
            siteURL: URL(string: parsed.siteURL),
            feedDescription: parsed.description.isEmpty ? nil : parsed.description
        )

        try await cloudKit.saveFeed(feed)

        let newArticles = parsed.articles.map { item in
            Article(
                feedID: feed.id,
                title: item.title,
                url: URL(string: item.link),
                author: item.author.isEmpty ? nil : item.author,
                summary: item.summary.isEmpty ? nil : item.summary,
                content: item.content.isEmpty ? nil : item.content,
                imageURL: URL(string: item.imageURL),
                publishedAt: RSSParser.parseDate(item.pubDate)
            )
        }

        articles[feed.id] = newArticles
        saveCachedArticles()
        return feed
    }

    func removeFeed(_ feed: Feed) async throws {
        try await cloudKit.deleteFeed(feed)
        articles.removeValue(forKey: feed.id)
        offlineManager.removeArticles(for: feed.id)
        saveCachedArticles()
    }

    func refreshAllFeeds() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await cloudKit.syncAll()

        await withTaskGroup(of: Void.self) { group in
            for feed in cloudKit.feeds {
                group.addTask { [weak self] in
                    await self?.refreshFeed(feed)
                }
            }
        }

        saveCachedArticles()
        updateUnreadCounts()
    }

    func refreshFeed(_ feed: Feed) async {
        do {
            let data = try await fetchData(from: feed.url)
            let parser = RSSParser()
            guard let parsed = parser.parse(data: data) else { return }

            let existingIDs = Set((articles[feed.id] ?? []).compactMap { $0.url?.absoluteString })

            let newArticles = parsed.articles.compactMap { item -> Article? in
                guard !existingIDs.contains(item.link) else { return nil }
                return Article(
                    feedID: feed.id,
                    title: item.title,
                    url: URL(string: item.link),
                    author: item.author.isEmpty ? nil : item.author,
                    summary: item.summary.isEmpty ? nil : item.summary,
                    content: item.content.isEmpty ? nil : item.content,
                    imageURL: URL(string: item.imageURL),
                    publishedAt: RSSParser.parseDate(item.pubDate)
                )
            }

            if !newArticles.isEmpty {
                var existing = articles[feed.id] ?? []
                existing.insert(contentsOf: newArticles, at: 0)
                articles[feed.id] = existing
            }
        } catch {
            print("Failed to refresh feed \(feed.title): \(error.localizedDescription)")
        }
    }

    // MARK: - Article State

    func markAsRead(_ article: Article) {
        guard let feedArticles = articles[article.feedID],
              let index = feedArticles.firstIndex(where: { $0.id == article.id }) else { return }
        articles[article.feedID]?[index].isRead = true
        saveCachedArticles()
        updateUnreadCounts()
    }

    func toggleStarred(_ article: Article) {
        guard let feedArticles = articles[article.feedID],
              let index = feedArticles.firstIndex(where: { $0.id == article.id }) else { return }
        articles[article.feedID]?[index].isStarred.toggle()
        saveCachedArticles()
    }

    func markAllAsRead(for feedID: UUID) {
        guard let feedArticles = articles[feedID] else { return }
        articles[feedID] = feedArticles.map { var a = $0; a.isRead = true; return a }
        saveCachedArticles()
        updateUnreadCounts()
    }

    func markAllAsRead() {
        for feedID in articles.keys {
            markAllAsRead(for: feedID)
        }
    }

    // MARK: - Private

    private func fetchData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FeedError.networkError
        }
        return data
    }

    private func updateUnreadCounts() {
        for i in cloudKit.feeds.indices {
            let feedID = cloudKit.feeds[i].id
            cloudKit.feeds[i].unreadCount = (articles[feedID] ?? []).filter { !$0.isRead }.count
        }
    }

    // MARK: - Local Cache

    private var cacheURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("articles_cache.json")
    }

    private func saveCachedArticles() {
        do {
            let data = try JSONEncoder().encode(articles)
            try data.write(to: cacheURL)
        } catch {
            print("Failed to cache articles: \(error)")
        }
    }

    private func loadCachedArticles() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode([UUID: [Article]].self, from: data) else { return }
        articles = cached
    }
}

enum FeedError: LocalizedError {
    case parseError
    case networkError
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .parseError: return "Could not parse the feed. Please check the URL."
        case .networkError: return "Network error. Please check your connection."
        case .invalidURL: return "Invalid feed URL."
        }
    }
}
