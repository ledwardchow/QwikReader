import SwiftUI

@MainActor
final class ImageCache: ObservableObject {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        cache.countLimit = 200
    }

    func image(for url: URL) async -> UIImage? {
        let key = url.absoluteString as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let filePath = cacheDirectory.appendingPathComponent(url.absoluteString.hashString)
        if let data = try? Data(contentsOf: filePath), let image = UIImage(data: data) {
            cache.setObject(image, forKey: key)
            return image
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                cache.setObject(image, forKey: key)
                try? data.write(to: filePath)
                return image
            }
        } catch {
            // Silently fail
        }
        return nil
    }

    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

extension String {
    var hashString: String {
        let data = Data(utf8)
        var hash: UInt64 = 5381
        for byte in data {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(hash)
    }
}
