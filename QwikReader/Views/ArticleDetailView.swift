import SwiftUI
import SafariServices
import WebKit

struct ArticleDetailView: View {
    let article: Article

    @ObservedObject var feedManager = FeedManager.shared
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var offlineManager = OfflineManager.shared
    @ObservedObject var cloudKit = CloudKitManager.shared
    @ObservedObject var readabilityExtractor = ReadabilityExtractor.shared

    @State private var showWebView = false
    @State private var showShareSheet = false
    @State private var showThemePicker = false
    @State private var isReaderViewActive = false
    @State private var readerContent: String?
    @State private var showReaderError = false
    @State private var readerError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                articleHeader

                Divider()

                // Content
                articleBody

                Spacer(minLength: 60)
            }
            .padding()
        }
        .background(themeManager.readerTheme.backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    feedManager.toggleStarred(article)
                } label: {
                    Image(systemName: article.isStarred ? "star.fill" : "star")
                        .foregroundStyle(article.isStarred ? .yellow : .secondary)
                }

                if article.url != nil {
                    Button {
                        if isReaderViewActive {
                            isReaderViewActive = false
                        } else {
                            Task {
                                let content = await readabilityExtractor.extract(for: article)
                                if let content {
                                    readerContent = content
                                    isReaderViewActive = true
                                    webViewHeight = 100
                                } else if case .failed(let msg) = readabilityExtractor.extractionState[article.id] {
                                    readerError = msg
                                    showReaderError = true
                                }
                            }
                        }
                    } label: {
                        Image(systemName: isReaderViewActive ? "doc.plaintext.fill" : "doc.plaintext")
                    }

                    Button {
                        showWebView = true
                    } label: {
                        Image(systemName: "safari")
                    }
                }

                Menu {
                    Button {
                        showThemePicker.toggle()
                    } label: {
                        Label("Reader Settings", systemImage: "textformat.size")
                    }

                    if let url = article.url {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }

                    Button {
                        Task {
                            let updated = await offlineManager.downloadArticle(article)
                            if let index = feedManager.articles[article.feedID]?.firstIndex(where: { $0.id == article.id }) {
                                feedManager.articles[article.feedID]?[index] = updated
                            }
                        }
                    } label: {
                        Label(
                            article.isDownloaded ? "Downloaded" : "Download for Offline",
                            systemImage: article.isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle"
                        )
                    }
                    .disabled(article.isDownloaded)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showWebView) {
            if let url = article.url {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showThemePicker) {
            readerSettings
        }
        .overlay {
            if case .loading = readabilityExtractor.extractionState[article.id] {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading Reading View...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.readerTheme.backgroundColor.opacity(0.9))
            }
        }
        .alert("Reading View Unavailable", isPresented: $showReaderError) {
            Button("OK") {}
        } message: {
            Text(readerError ?? "Could not extract article content.")
        }
        .onAppear {
            feedManager.markAsRead(article)

            // Auto-activate reader view if cached and setting is on
            if themeManager.autoCacheReaderView,
               let cached = readabilityExtractor.getCachedContent(article.id) {
                readerContent = cached
                isReaderViewActive = true
                webViewHeight = 100
            }
        }
    }

    // MARK: - Header

    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let feedTitle = cloudKit.feeds.first(where: { $0.id == article.feedID })?.title {
                Text(feedTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
                    .textCase(.uppercase)
            }

            Text(article.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(themeManager.readerTheme.textColor)

            HStack(spacing: 12) {
                if let author = article.author {
                    Label(author, systemImage: "person")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.readerTheme.secondaryTextColor)
                }

                if let date = article.publishedAt {
                    Label {
                        Text(date, style: .date)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.subheadline)
                    .foregroundStyle(themeManager.readerTheme.secondaryTextColor)
                }
            }

            if let imageURL = article.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 250)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }

    // MARK: - Body

    @State private var webViewHeight: CGFloat = 100

    private var articleBody: some View {
        Group {
            if isReaderViewActive, let readerContent {
                HTMLContentView(
                    html: readerContent,
                    theme: themeManager.readerTheme,
                    fontSize: themeManager.readerFontSize,
                    contentHeight: $webViewHeight
                )
                .frame(height: webViewHeight)
            } else {
                let content = article.content ?? article.summary ?? ""
                if content.contains("<") {
                    HTMLContentView(
                        html: content,
                        theme: themeManager.readerTheme,
                        fontSize: themeManager.readerFontSize,
                        contentHeight: $webViewHeight
                    )
                    .frame(height: webViewHeight)
                } else {
                    Text(HTMLParser.stripHTML(content))
                        .font(.system(size: themeManager.readerFontSize))
                        .foregroundStyle(themeManager.readerTheme.textColor)
                        .lineSpacing(6)
                }
            }
        }
    }

    // MARK: - Reader Settings Sheet

    private var readerSettings: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Theme", selection: $themeManager.readerTheme) {
                        ForEach(ReaderTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Font Size") {
                    HStack {
                        Text("A")
                            .font(.caption)
                        Slider(value: $themeManager.readerFontSize, in: 12...28, step: 1)
                        Text("A")
                            .font(.title)
                    }
                    Text("Preview: \(Int(themeManager.readerFontSize))pt")
                        .font(.system(size: themeManager.readerFontSize))
                }
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showThemePicker = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - SFSafariViewController wrapper (full-bleed, gets user's content blockers)

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = .systemOrange
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - HTML Content WebView with built-in ad blocking

struct HTMLContentView: UIViewRepresentable {
    let html: String
    let theme: ReaderTheme
    let fontSize: Double
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Compile and attach content blocking rules
        ContentBlockerManager.shared.attachRules(to: config.userContentController)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let bgColor: String
        let textColor: String
        switch theme {
        case .light:
            bgColor = "#FFFFFF"; textColor = "#000000"
        case .sepia:
            bgColor = "#F7EDD9"; textColor = "#453521"
        case .gray:
            bgColor = "#E5E5EA"; textColor = "#000000"
        case .dark:
            bgColor = "#1C1C1E"; textColor = "#E5E5E5"
        }

        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { box-sizing: border-box; }
                html, body {
                    margin: 0;
                    padding: 0;
                    overflow: hidden;
                }
                body {
                    font-family: -apple-system, system-ui, sans-serif;
                    font-size: \(Int(fontSize))px;
                    line-height: 1.6;
                    color: \(textColor);
                    background-color: \(bgColor);
                    word-wrap: break-word;
                    -webkit-text-size-adjust: 100%;
                }
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    margin: 12px 0;
                    display: block;
                }
                a { color: #FF6F60; text-decoration: none; }
                pre, code {
                    background: rgba(128,128,128,0.15);
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-size: 0.9em;
                    overflow-x: auto;
                }
                blockquote {
                    border-left: 3px solid #FF6F60;
                    margin-left: 0;
                    padding-left: 16px;
                    color: \(textColor)CC;
                }
                h1, h2, h3, h4, h5, h6 {
                    line-height: 1.3;
                    margin-top: 1.2em;
                    margin-bottom: 0.5em;
                }
                p { margin: 0.8em 0; }
                table {
                    border-collapse: collapse;
                    width: 100%;
                    margin: 12px 0;
                }
                th, td {
                    border: 1px solid rgba(128,128,128,0.3);
                    padding: 8px;
                    text-align: left;
                }
                figure { margin: 12px 0; }
                figcaption { font-size: 0.85em; color: \(textColor)99; text-align: center; }
                iframe { max-width: 100%; }
            </style>
        </head>
        <body>
            <div id="qr-content">\(html)</div>
            <div style="height: 1px;"></div>
        </body>
        </html>
        """

        let currentHTML = styledHTML
        if context.coordinator.lastLoadedHTML != currentHTML {
            context.coordinator.lastLoadedHTML = currentHTML
            webView.loadHTMLString(styledHTML, baseURL: nil)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var contentHeight: CGFloat
        var lastLoadedHTML: String?
        weak var webView: WKWebView?
        private var heightObservation: NSKeyValueObservation?

        init(contentHeight: Binding<CGFloat>) {
            _contentHeight = contentHeight
            super.init()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            measureHeight()

            // Also observe contentSize changes for images that load async
            heightObservation = webView.scrollView.observe(\.contentSize, options: [.new]) { [weak self] scrollView, _ in
                let newHeight = scrollView.contentSize.height
                if newHeight > 0 {
                    DispatchQueue.main.async {
                        self?.contentHeight = newHeight
                    }
                }
            }
        }

        // Links tapped inside the article open in Safari (with user's content blockers)
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        private func measureHeight() {
            guard let webView else { return }
            let js = "document.getElementById('qr-content').offsetHeight"
            webView.evaluateJavaScript(js) { [weak self] result, _ in
                if let height = result as? CGFloat, height > 0 {
                    DispatchQueue.main.async {
                        self?.contentHeight = height + 20
                    }
                }
            }
        }

        deinit {
            heightObservation?.invalidate()
        }
    }
}

// MARK: - Built-in Content Blocker

final class ContentBlockerManager {
    static let shared = ContentBlockerManager()

    private var compiledRuleList: WKContentRuleList?
    private let ruleListID = "QwikReaderBlocker"

    private init() {
        compileRules()
    }

    /// Blocks common ad/tracking domains and popups
    private var blockingRules: String {
        """
        [
            {
                "trigger": {
                    "url-filter": ".*(doubleclick\\\\.net|googlesyndication\\\\.com|googleadservices\\\\.com|google-analytics\\\\.com|adnxs\\\\.com|adsrvr\\\\.org|amazon-adsystem\\\\.com|scorecardresearch\\\\.com|quantserve\\\\.com|outbrain\\\\.com|taboola\\\\.com|criteo\\\\.com|rubiconproject\\\\.com|pubmatic\\\\.com|openx\\\\.net|casalemedia\\\\.com|moatads\\\\.com|chartbeat\\\\.com|hotjar\\\\.com|newrelic\\\\.com|optimizely\\\\.com|segment\\\\.com|mixpanel\\\\.com|amplitude\\\\.com|tealium\\\\.com|nr-data\\\\.net).*"
                },
                "action": { "type": "block" }
            },
            {
                "trigger": {
                    "url-filter": ".*(pagead|ad_click|doubleclick|adserver|adtrack|advert|pixel\\\\.gif|tracker|tracking|analytics|telemetry|beacon).*",
                    "load-type": ["third-party"]
                },
                "action": { "type": "block" }
            },
            {
                "trigger": {
                    "url-filter": ".*",
                    "resource-type": ["popup"]
                },
                "action": { "type": "block" }
            }
        ]
        """
    }

    private func compileRules() {
        let store = WKContentRuleListStore.default()

        // Try to use cached rules first
        store?.lookUpContentRuleList(forIdentifier: ruleListID) { [weak self] ruleList, _ in
            if let ruleList {
                self?.compiledRuleList = ruleList
            } else {
                self?.recompile()
            }
        }
    }

    private func recompile() {
        WKContentRuleListStore.default()?.compileContentRuleList(
            forIdentifier: ruleListID,
            encodedContentRuleList: blockingRules
        ) { [weak self] ruleList, error in
            if let ruleList {
                self?.compiledRuleList = ruleList
            } else if let error {
                print("Content blocker compile error: \(error.localizedDescription)")
            }
        }
    }

    func attachRules(to userContentController: WKUserContentController) {
        if let compiledRuleList {
            userContentController.add(compiledRuleList)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ArticleDetailView(article: PreviewFixtures.article)
    }
}
#endif
