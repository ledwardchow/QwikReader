import Foundation
import WebKit

@MainActor
final class ReadabilityExtractor: ObservableObject {
    static let shared = ReadabilityExtractor()

    enum ExtractionState {
        case idle
        case loading
        case extracted(String)
        case failed(String)
    }

    @Published var extractionState: [UUID: ExtractionState] = [:]
    @Published var cachedSizeString: String = "0 KB"

    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ReaderViewCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        cachedSizeString = cacheSize()
    }

    // MARK: - Public

    func extract(for article: Article) async -> String? {
        // Check cache first
        if let cached = getCachedContent(article.id) {
            extractionState[article.id] = .extracted(cached)
            return cached
        }

        guard let url = article.url else {
            extractionState[article.id] = .failed("No article URL available.")
            return nil
        }

        extractionState[article.id] = .loading

        do {
            let html = try await loadAndExtract(url: url)

            // Validate we got meaningful content
            let strippedLength = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines).count
            guard strippedLength > 100 else {
                extractionState[article.id] = .failed("Could not extract readable content.")
                return nil
            }

            // Cache to disk
            cacheContent(html, for: article.id)

            extractionState[article.id] = .extracted(html)
            return html
        } catch {
            extractionState[article.id] = .failed(error.localizedDescription)
            return nil
        }
    }

    func getCachedContent(_ articleID: UUID) -> String? {
        let path = cacheDirectory
            .appendingPathComponent(articleID.uuidString)
            .appendingPathComponent("reader.html")
        return try? String(contentsOf: path, encoding: .utf8)
    }

    func cacheArticles(_ articles: [Article]) async {
        for article in articles {
            guard getCachedContent(article.id) == nil else { continue }
            _ = await extract(for: article)
        }
    }

    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        refreshCacheSize()
    }

    func cacheSize() -> String {
        let size = directorySize(url: cacheDirectory)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    func refreshCacheSize() {
        cachedSizeString = cacheSize()
    }

    // MARK: - Private

    private func loadAndExtract(url: URL) async throws -> String {
        let config = WKWebViewConfiguration()
        ContentBlockerManager.shared.attachRules(to: config.userContentController)

        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 812), configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        let coordinator = ExtractionCoordinator()
        webView.navigationDelegate = coordinator

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        webView.load(request)

        // Wait for page load with timeout
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await coordinator.waitForLoad()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(15))
                throw ExtractionError.timeout
            }
            // First to finish wins; cancel the other
            try await group.next()
            group.cancelAll()
        }

        // Brief delay for JS-rendered content
        try? await Task.sleep(for: .milliseconds(500))

        // Run extraction
        let result = try await webView.evaluateJavaScript(Self.extractionJS)

        guard let jsonString = result as? String,
              let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let content = json["content"], !content.isEmpty else {
            throw ExtractionError.extractionFailed
        }

        return content
    }

    private func cacheContent(_ html: String, for articleID: UUID) {
        let articleDir = cacheDirectory.appendingPathComponent(articleID.uuidString, isDirectory: true)
        try? fileManager.createDirectory(at: articleDir, withIntermediateDirectories: true)
        let path = articleDir.appendingPathComponent("reader.html")
        try? html.write(to: path, atomically: true, encoding: .utf8)
        refreshCacheSize()
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

    // MARK: - Errors

    private enum ExtractionError: LocalizedError {
        case timeout
        case extractionFailed

        var errorDescription: String? {
            switch self {
            case .timeout: return "The page took too long to load."
            case .extractionFailed: return "Could not extract readable content from this page."
            }
        }
    }

    // MARK: - Navigation Coordinator

    private class ExtractionCoordinator: NSObject, WKNavigationDelegate {
        private var continuation: CheckedContinuation<Void, Error>?

        func waitForLoad() async throws {
            try await withCheckedThrowingContinuation { cont in
                self.continuation = cont
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            continuation?.resume()
            continuation = nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            continuation?.resume(throwing: error)
            continuation = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    // MARK: - JavaScript Extraction Script

    private static let extractionJS: String = """
    (function() {
        // Phase 1: Remove non-content elements
        var removeSelectors = [
            'script', 'style', 'noscript', 'iframe', 'svg',
            'nav', 'footer', 'header', 'aside',
            '[role="navigation"]', '[role="banner"]', '[role="contentinfo"]', '[role="complementary"]',
            '.sidebar', '.navigation', '.nav', '.menu', '.footer', '.header',
            '.ad', '.ads', '.advertisement', '.advert', '.ad-container',
            '.social-share', '.share-buttons', '.social-links', '.social',
            '.comments', '.comment-section', '#comments', '#disqus_thread',
            '.related-posts', '.related-articles', '.recommended',
            '.popup', '.modal', '.overlay', '.cookie-banner', '.cookie-notice',
            '.newsletter', '.newsletter-signup', '.subscribe',
            '.breadcrumb', '.breadcrumbs', '.pagination',
            '.widget', '.widgets', '.sidebar-widget'
        ];

        removeSelectors.forEach(function(sel) {
            try {
                document.querySelectorAll(sel).forEach(function(el) { el.remove(); });
            } catch(e) {}
        });

        // Phase 2: Score candidate containers
        var candidates = document.querySelectorAll('div, section, article, main, td, [role="main"]');
        var scores = new Map();

        candidates.forEach(function(el) {
            var score = 0;
            var tag = el.tagName.toLowerCase();
            var className = (el.className || '').toString().toLowerCase();
            var id = (el.id || '').toLowerCase();
            var combo = className + ' ' + id;

            // Tag bonuses
            if (tag === 'article') score += 20;
            if (tag === 'main' || el.getAttribute('role') === 'main') score += 15;
            if (tag === 'section') score += 3;

            // Class/ID bonuses
            if (/article|content|post|entry|story|body|text|main/.test(combo)) score += 25;
            if (/comment|sidebar|footer|nav|menu|widget|ad|social|promo|related|share|subscribe|newsletter/.test(combo)) score -= 25;

            // Count paragraphs
            var paragraphs = el.querySelectorAll('p');
            score += paragraphs.length * 3;

            // Text length bonus (capped)
            var textLen = (el.innerText || '').length;
            score += Math.min(Math.floor(textLen / 100), 5);

            // Link density penalty
            var linkText = 0;
            el.querySelectorAll('a').forEach(function(a) {
                linkText += (a.innerText || '').length;
            });
            var linkDensity = textLen > 0 ? linkText / textLen : 0;
            if (linkDensity > 0.5) score -= 30;
            if (linkDensity > 0.3) score -= 10;

            // Penalize very short containers
            if (textLen < 50) score -= 20;

            scores.set(el, score);

            // Propagate half score to parent
            var parent = el.parentElement;
            if (parent && scores.has(parent)) {
                scores.set(parent, scores.get(parent) + score * 0.5);
            } else if (parent) {
                scores.set(parent, score * 0.5);
            }
        });

        // Phase 3: Select best candidate
        var best = null;
        var bestScore = -Infinity;
        scores.forEach(function(score, el) {
            if (score > bestScore) {
                bestScore = score;
                best = el;
            }
        });

        if (!best || bestScore < 10) {
            best = document.body;
        }

        // Phase 4: Clean the selected element
        var clone = best.cloneNode(true);

        // Remove non-content elements from clone
        var removeFromClone = [
            'script', 'style', 'noscript', 'iframe', 'svg', 'nav', 'footer',
            'header', 'aside', 'form', 'input', 'button', 'select', 'textarea',
            '.ad', '.ads', '.advertisement', '.social-share', '.share-buttons',
            '.comments', '.related-posts', '.newsletter', '.subscribe',
            '.sidebar', '.widget', '.navigation', '.menu', '.breadcrumb', '.pagination'
        ];
        removeFromClone.forEach(function(sel) {
            try {
                clone.querySelectorAll(sel).forEach(function(el) { el.remove(); });
            } catch(e) {}
        });

        // Remove hidden elements
        clone.querySelectorAll('*').forEach(function(el) {
            var style = window.getComputedStyle(el);
            if (style && (style.display === 'none' || style.visibility === 'hidden')) {
                el.remove();
            }
        });

        // Remove empty elements (except img, br, hr, video, source)
        var keepEmpty = new Set(['IMG', 'BR', 'HR', 'VIDEO', 'SOURCE', 'IFRAME']);
        clone.querySelectorAll('*').forEach(function(el) {
            if (!keepEmpty.has(el.tagName) && !el.querySelector('img') && (el.innerText || '').trim() === '' && !el.querySelector('video')) {
                el.remove();
            }
        });

        // Convert relative URLs to absolute
        var baseUrl = window.location.origin;
        clone.querySelectorAll('img[src]').forEach(function(img) {
            var src = img.getAttribute('src');
            if (src && !src.startsWith('http') && !src.startsWith('data:')) {
                try {
                    img.setAttribute('src', new URL(src, window.location.href).href);
                } catch(e) {}
            }
        });
        clone.querySelectorAll('a[href]').forEach(function(a) {
            var href = a.getAttribute('href');
            if (href && !href.startsWith('http') && !href.startsWith('#') && !href.startsWith('mailto:')) {
                try {
                    a.setAttribute('href', new URL(href, window.location.href).href);
                } catch(e) {}
            }
        });

        // Strip inline styles
        clone.querySelectorAll('[style]').forEach(function(el) {
            el.removeAttribute('style');
        });

        // Remove class and id attributes to keep clean HTML
        clone.querySelectorAll('*').forEach(function(el) {
            el.removeAttribute('class');
            el.removeAttribute('id');
        });

        var content = clone.innerHTML || '';

        return JSON.stringify({
            content: content
        });
    })()
    """;
}
