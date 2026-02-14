import SwiftUI

struct AddFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var feedManager = FeedManager.shared
    @ObservedObject var cloudKit = CloudKitManager.shared

    @State private var urlString = ""
    @State private var selectedFolderID: UUID?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var addedFeed: Feed?

    @FocusState private var isURLFieldFocused: Bool

    private let suggestedFeeds: [SuggestedFeed] = [
        SuggestedFeed(name: "The Verge", url: "https://www.theverge.com/rss/index.xml"),
        SuggestedFeed(name: "Ars Technica", url: "https://feeds.arstechnica.com/arstechnica/index"),
        SuggestedFeed(name: "TechCrunch", url: "https://techcrunch.com/feed/"),
        SuggestedFeed(name: "Hacker News", url: "https://hnrss.org/frontpage"),
        SuggestedFeed(name: "BBC News", url: "https://feeds.bbci.co.uk/news/rss.xml"),
        SuggestedFeed(name: "Reuters", url: "https://feeds.reuters.com/reuters/topNews"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "link")
                            .foregroundStyle(.secondary)
                        TextField("https://example.com/feed.xml", text: $urlString)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($isURLFieldFocused)
                            .submitLabel(.go)
                            .onSubmit { addFeed() }
                    }

                    if !cloudKit.folders.isEmpty {
                        Picker("Folder", selection: $selectedFolderID) {
                            Text("No Folder").tag(nil as UUID?)
                            ForEach(cloudKit.folders) { folder in
                                Text(folder.name).tag(folder.id as UUID?)
                            }
                        }
                    }
                } header: {
                    Text("Feed URL")
                } footer: {
                    Text("Enter the RSS or Atom feed URL. Most blogs and news sites provide one.")
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                if let feed = addedFeed {
                    Section {
                        Label {
                            VStack(alignment: .leading) {
                                Text(feed.title)
                                    .fontWeight(.medium)
                                if let desc = feed.feedDescription {
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    } header: {
                        Text("Added Successfully")
                    }
                }

                Section {
                    ForEach(suggestedFeeds) { feed in
                        Button {
                            urlString = feed.url
                            addFeed()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(feed.name)
                                        .foregroundStyle(.primary)
                                    Text(feed.url)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .disabled(cloudKit.feeds.contains(where: { $0.url.absoluteString == feed.url }))
                    }
                } header: {
                    Text("Suggested Feeds")
                }
            }
            .navigationTitle("Add Feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Add") { addFeed() }
                            .disabled(urlString.trimmingCharacters(in: .whitespaces).isEmpty)
                            .fontWeight(.semibold)
                    }
                }
            }
            .onAppear { isURLFieldFocused = true }
        }
    }

    private func addFeed() {
        var cleaned = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.hasPrefix("http://") && !cleaned.hasPrefix("https://") {
            cleaned = "https://" + cleaned
        }
        guard let url = URL(string: cleaned) else {
            errorMessage = "Invalid URL. Please check and try again."
            return
        }

        errorMessage = nil
        isLoading = true

        Task {
            do {
                var feed = try await feedManager.addFeed(url: url)
                if let folderID = selectedFolderID {
                    feed.folderID = folderID
                    try await cloudKit.saveFeed(feed)
                }
                addedFeed = feed
                urlString = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

struct SuggestedFeed: Identifiable {
    let id: String
    let name: String
    let url: String

    init(name: String, url: String) {
        self.id = url
        self.name = name
        self.url = url
    }
}

#Preview {
    AddFeedView()
}
