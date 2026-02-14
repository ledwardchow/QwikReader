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
