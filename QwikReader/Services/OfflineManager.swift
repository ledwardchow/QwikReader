import Foundation
import SwiftUI

@MainActor
final class OfflineManager: ObservableObject {
    static let shared = OfflineManager()

    @Published var downloadingArticles: Set<UUID> = []

    private let fileManager = FileManager.default
    private let offlineDirectory: URL
    private let session: URLSession

    private init() {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        offlineDirectory = paths[0].appendingPathComponent("OfflineArticles", isDirectory: true)
        try? fileManager.createDirectory(at: offlineDirectory, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        session = URLSession(configuration: config)
    }

    func downloadArticle(_ article: Article) async -> Article {
        guard !downloadingArticles.contains(article.id) else { return article }
        downloadingArticles.insert(article.id)
        defer { downloadingArticles.remove(article.id) }

        var updated = article
        let articleDir = offlineDirectory.appendingPathComponent(article.id.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: articleDir, withIntermediateDirectories: true)

        // Download the full article HTML if we have a URL
        if let url = article.url {
            do {
                let (data, _) = try await session.data(from: url)
                let htmlPath = articleDir.appendingPathComponent("article.html")
                try data.write(to: htmlPath)

                // Extract and cache images from the content
                if let html = String(data: data, encoding: .utf8) {
                    let imageURLs = extractImageURLs(from: html)
                    await downloadImages(imageURLs, to: articleDir)
                }

                updated.isDownloaded = true
            } catch {
                print("Failed to download article: \(error.localizedDescription)")
            }
        }

        // Download the thumbnail
        if let imageURL = article.imageURL {
            await downloadImages([imageURL], to: articleDir)
        }

        // Save article metadata
        let metadataPath = articleDir.appendingPathComponent("metadata.json")
        if let data = try? JSONEncoder().encode(updated) {
            try? data.write(to: metadataPath)
        }

        return updated
    }

    func downloadAllArticles(for feedID: UUID) async {
        let feedManager = FeedManager.shared
        let articles = feedManager.articles(for: feedID)

        await withTaskGroup(of: Article.self) { group in
            for article in articles.prefix(20) where !article.isDownloaded {
                group.addTask { [weak self] in
                    guard let self else { return article }
                    return await self.downloadArticle(article)
                }
            }

            for await updated in group {
                if let index = feedManager.articles[feedID]?.firstIndex(where: { $0.id == updated.id }) {
                    feedManager.articles[feedID]?[index] = updated
                }
            }
        }
    }

    func isArticleAvailableOffline(_ articleID: UUID) -> Bool {
        let articleDir = offlineDirectory.appendingPathComponent(articleID.uuidString)
        return fileManager.fileExists(atPath: articleDir.appendingPathComponent("metadata.json").path)
    }

    func getOfflineContent(_ articleID: UUID) -> String? {
        let htmlPath = offlineDirectory
            .appendingPathComponent(articleID.uuidString)
            .appendingPathComponent("article.html")
        return try? String(contentsOf: htmlPath, encoding: .utf8)
    }

    func removeArticle(_ articleID: UUID) {
        let articleDir = offlineDirectory.appendingPathComponent(articleID.uuidString)
        try? fileManager.removeItem(at: articleDir)
    }

    func removeArticles(for feedID: UUID) {
        let feedManager = FeedManager.shared
        for article in feedManager.articles(for: feedID) {
            removeArticle(article.id)
        }
    }

    func offlineStorageSize() -> String {
        let size = directorySize(url: offlineDirectory)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    func clearAllOfflineContent() {
        try? fileManager.removeItem(at: offlineDirectory)
        try? fileManager.createDirectory(at: offlineDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private

    private func extractImageURLs(from html: String) -> [URL] {
        let pattern = "<img[^>]+src=[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)

        return matches.compactMap { match in
            guard let urlRange = Range(match.range(at: 1), in: html) else { return nil }
            return URL(string: String(html[urlRange]))
        }
    }

    private func downloadImages(_ urls: [URL], to directory: URL) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls.prefix(10) {
                group.addTask { [weak self] in
                    guard let self else { return }
                    do {
                        let (data, _) = try await self.session.data(from: url)
                        let filename = url.lastPathComponent.isEmpty ? url.absoluteString.hashString : url.lastPathComponent
                        let path = directory.appendingPathComponent(filename)
                        try data.write(to: path)
                    } catch {
                        // Silently fail for individual images
                    }
                }
            }
        }
    }

    private func directorySize(url: URL) -> UInt64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        return total
    }
}
