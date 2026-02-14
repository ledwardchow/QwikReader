import Foundation

struct Article: Identifiable, Codable, Hashable {
    var id: UUID
    var feedID: UUID
    var title: String
    var url: URL?
    var author: String?
    var summary: String?
    var content: String?
    var imageURL: URL?
    var publishedAt: Date?
    var isRead: Bool
    var isStarred: Bool
    var isDownloaded: Bool

    init(
        id: UUID = UUID(),
        feedID: UUID,
        title: String,
        url: URL? = nil,
        author: String? = nil,
        summary: String? = nil,
        content: String? = nil,
        imageURL: URL? = nil,
        publishedAt: Date? = nil,
        isRead: Bool = false,
        isStarred: Bool = false,
        isDownloaded: Bool = false
    ) {
        self.id = id
        self.feedID = feedID
        self.title = title
        self.url = url
        self.author = author
        self.summary = summary
        self.content = content
        self.imageURL = imageURL
        self.publishedAt = publishedAt
        self.isRead = isRead
        self.isStarred = isStarred
        self.isDownloaded = isDownloaded
    }

    var displaySummary: String {
        if let summary, !summary.isEmpty {
            return HTMLParser.stripHTML(summary)
        }
        if let content, !content.isEmpty {
            let stripped = HTMLParser.stripHTML(content)
            return String(stripped.prefix(200))
        }
        return ""
    }

    var relativeDate: String {
        guard let date = publishedAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#if DEBUG
enum PreviewFixtures {
    static let folder = FeedFolder(
        id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        name: "Tech",
        sortOrder: 0
    )

    static let feed = Feed(
        id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
        title: "QwikReader Blog",
        url: URL(string: "https://example.com/feed.xml")!,
        siteURL: URL(string: "https://example.com"),
        feedDescription: "A sample feed for previews.",
        iconURL: URL(string: "https://picsum.photos/40"),
        folderID: folder.id
    )

    static let article = Article(
        id: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
        feedID: feed.id,
        title: "SwiftUI Previews in Real Projects",
        url: URL(string: "https://example.com/articles/swiftui-previews"),
        author: "QwikReader Team",
        summary: "A concise summary used for canvas previews.",
        content: """
        <p>SwiftUI previews render faster when views are seeded with local fixtures.</p>
        <p>This sample content helps canvas display realistic layout and typography.</p>
        """,
        imageURL: URL(string: "https://picsum.photos/640/360"),
        publishedAt: Calendar.current.date(byAdding: .hour, value: -3, to: Date()),
        isRead: false,
        isStarred: true,
        isDownloaded: true
    )

    static let articles: [Article] = [
        article,
        Article(
            feedID: feed.id,
            title: "Offline Reading and Caching",
            url: URL(string: "https://example.com/articles/offline"),
            author: "Editor",
            summary: "Another preview row for list rendering.",
            content: "Short article body for previews.",
            imageURL: URL(string: "https://picsum.photos/420/240"),
            publishedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            isRead: true,
            isStarred: false,
            isDownloaded: false
        )
    ]
}

extension ProcessInfo {
    static var isRunningForPreviews: Bool {
        processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
#endif
