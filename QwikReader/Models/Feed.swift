import Foundation

struct Feed: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var url: URL
    var siteURL: URL?
    var feedDescription: String?
    var iconURL: URL?
    var folderID: UUID?
    var lastFetchedAt: Date?
    var unreadCount: Int
    var addedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        siteURL: URL? = nil,
        feedDescription: String? = nil,
        iconURL: URL? = nil,
        folderID: UUID? = nil,
        lastFetchedAt: Date? = nil,
        unreadCount: Int = 0,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.siteURL = siteURL
        self.feedDescription = feedDescription
        self.iconURL = iconURL
        self.folderID = folderID
        self.lastFetchedAt = lastFetchedAt
        self.unreadCount = unreadCount
        self.addedAt = addedAt
    }
}
