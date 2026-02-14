import Foundation
import Combine

@MainActor
final class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let feedsKey = "synced_feeds"
    private let foldersKey = "synced_folders"

    @Published var feeds: [Feed] = []
    @Published var folders: [FeedFolder] = []
    @Published var iCloudAvailable = false

    private init() {
        loadFromStore()
        checkiCloudStatus()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        kvStore.synchronize()
    }

    // MARK: - iCloud Status

    private func checkiCloudStatus() {
        iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
    }

    @objc private nonisolated func kvStoreDidChange(_ notification: Notification) {
        Task { @MainActor in
            self.loadFromStore()
        }
    }

    // MARK: - Persistence

    private func loadFromStore() {
        if let data = kvStore.data(forKey: feedsKey),
           let decoded = try? JSONDecoder().decode([Feed].self, from: data) {
            feeds = decoded
        }
        if let data = kvStore.data(forKey: foldersKey),
           let decoded = try? JSONDecoder().decode([FeedFolder].self, from: data) {
            folders = decoded
        }
    }

    private func saveFeeds() {
        if let data = try? JSONEncoder().encode(feeds) {
            kvStore.set(data, forKey: feedsKey)
            kvStore.synchronize()
        }
    }

    private func saveFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            kvStore.set(data, forKey: foldersKey)
            kvStore.synchronize()
        }
    }

    // MARK: - Feeds

    func saveFeed(_ feed: Feed) async throws {
        if let index = feeds.firstIndex(where: { $0.id == feed.id }) {
            feeds[index] = feed
        } else {
            feeds.append(feed)
        }
        saveFeeds()
    }

    func deleteFeed(_ feed: Feed) async throws {
        feeds.removeAll { $0.id == feed.id }
        saveFeeds()
    }

    // MARK: - Folders

    func saveFolder(_ folder: FeedFolder) async throws {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
        } else {
            folders.append(folder)
        }
        saveFolders()
    }

    func deleteFolder(_ folder: FeedFolder) async throws {
        folders.removeAll { $0.id == folder.id }
        // Unassign feeds from this folder
        for i in feeds.indices where feeds[i].folderID == folder.id {
            feeds[i].folderID = nil
        }
        saveFolders()
        saveFeeds()
    }

    // MARK: - Sync All

    func syncAll() async {
        kvStore.synchronize()
        loadFromStore()
    }
}
