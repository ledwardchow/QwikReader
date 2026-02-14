import SwiftUI

struct SidebarView: View {
    @Binding var selectedItem: SidebarItem?

    @ObservedObject var cloudKit = CloudKitManager.shared
    @ObservedObject var feedManager = FeedManager.shared
    @State private var showingAddFeed = false
    @State private var showingAddFolder = false
    @State private var showingSettings = false
    @State private var newFolderName = ""
    @State private var editMode: EditMode = .inactive
    @State private var feedToDelete: Feed?
    @State private var folderToDelete: FeedFolder?

    /// When true, the List uses a selection binding (iPad NavigationSplitView).
    /// When false, NavigationLink values drive NavigationStack (iPhone).
    private var usesSelectionBinding: Bool

    init(selectedItem: Binding<SidebarItem?>) {
        self._selectedItem = selectedItem
        self.usesSelectionBinding = true
    }

    init() {
        self._selectedItem = .constant(nil)
        self.usesSelectionBinding = false
    }

    var body: some View {
        listContent
        .listStyle(.plain)
        .navigationTitle("QwikReader")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingAddFeed = true
                    } label: {
                        Label("Add Feed", systemImage: "plus.circle")
                    }
                    Button {
                        showingAddFolder = true
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Button {
                        Task { await feedManager.refreshAllFeeds() }
                    } label: {
                        HStack(spacing: 6) {
                            if feedManager.isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(feedManager.isRefreshing ? "Refreshing..." : "Refresh")
                                .font(.subheadline)
                        }
                    }
                    .disabled(feedManager.isRefreshing)
                    if let lastRefreshed = feedManager.lastRefreshedAt {
                        TimelineView(.periodic(from: .now, by: 60)) { _ in
                            Text("Updated \(lastRefreshed, format: .relative(presentation: .named))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
        .environment(\.editMode, $editMode)
        .sheet(isPresented: $showingAddFeed) {
            AddFeedView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("New Folder", isPresented: $showingAddFolder) {
            TextField("Folder Name", text: $newFolderName)
            Button("Cancel", role: .cancel) { newFolderName = "" }
            Button("Create") {
                let name = newFolderName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                Task {
                    try? await cloudKit.saveFolder(FeedFolder(name: name, sortOrder: cloudKit.folders.count))
                    newFolderName = ""
                }
            }
        }
        .alert("Delete Feed", isPresented: Binding(
            get: { feedToDelete != nil },
            set: { if !$0 { feedToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { feedToDelete = nil }
            Button("Delete", role: .destructive) {
                if let feed = feedToDelete {
                    Task { try? await feedManager.removeFeed(feed) }
                    feedToDelete = nil
                }
            }
        } message: {
            if let feed = feedToDelete {
                Text("Are you sure you want to delete \"\(feed.title)\"? All cached articles will be removed.")
            }
        }
        .alert("Delete Folder", isPresented: Binding(
            get: { folderToDelete != nil },
            set: { if !$0 { folderToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { folderToDelete = nil }
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete {
                    Task { try? await cloudKit.deleteFolder(folder) }
                    folderToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this folder? Feeds inside will be moved out of the folder.")
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if usesSelectionBinding {
            List(selection: $selectedItem) {
                listSections
            }
        } else {
            List {
                listSections
            }
        }
    }

    @ViewBuilder
    private var listSections: some View {
        // Smart Feeds Section
        Section {
            NavigationLink(value: SidebarItem.allArticles) {
                Label {
                    HStack {
                        Text("All Articles")
                        Spacer()
                        if feedManager.unreadArticles.count > 0 {
                            Text("\(feedManager.unreadArticles.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
                } icon: {
                    Image(systemName: "tray.full")
                        .foregroundStyle(.blue)
                }
            }

            NavigationLink(value: SidebarItem.unread) {
                Label {
                    HStack {
                        Text("Unread")
                        Spacer()
                        if feedManager.unreadArticles.count > 0 {
                            Text("\(feedManager.unreadArticles.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "envelope.badge")
                        .foregroundStyle(.orange)
                }
            }

            NavigationLink(value: SidebarItem.starred) {
                Label {
                    Text("Starred")
                } icon: {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }
        } header: {
            Text("Smart Feeds")
        }

        // Folders Section
        if !cloudKit.folders.isEmpty {
            Section {
                ForEach(cloudKit.folders) { folder in
                    NavigationLink(value: SidebarItem.folder(folder)) {
                        Label {
                            HStack {
                                Text(folder.name)
                                Spacer()
                                let count = feedManager.articlesInFolder(folder.id).filter { !$0.isRead }.count
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.indigo)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            folderToDelete = folder
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            let feedIDs = cloudKit.feeds.filter { $0.folderID == folder.id }.map(\.id)
                            for feedID in feedIDs {
                                feedManager.markAllAsRead(for: feedID)
                            }
                        } label: {
                            Label("Mark as Read", systemImage: "envelope.open")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete { offsets in
                    if let index = offsets.first {
                        folderToDelete = cloudKit.folders[index]
                    }
                }
            } header: {
                Text("Folders")
            }
        }

        // Feeds Section
        Section {
            ForEach(cloudKit.feeds) { feed in
                NavigationLink(value: SidebarItem.feed(feed)) {
                    FeedRowView(feed: feed)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        feedToDelete = feed
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        feedManager.markAllAsRead(for: feed.id)
                    } label: {
                        Label("Mark as Read", systemImage: "envelope.open")
                    }
                    .tint(.blue)
                }
            }
            .onDelete { offsets in
                if let index = offsets.first {
                    feedToDelete = cloudKit.feeds[index]
                }
            }
        } header: {
            HStack {
                Text("Feeds")
                Spacer()
                Text("\(cloudKit.feeds.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

}

struct FeedRowView: View {
    let feed: Feed
    @ObservedObject var feedManager = FeedManager.shared

    var body: some View {
        Label {
            HStack {
                Text(feed.title)
                    .lineLimit(1)
                Spacer()
                let count = feedManager.articles(for: feed.id).filter { !$0.isRead }.count
                if count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            if let iconURL = feed.iconURL {
                AsyncImage(url: iconURL) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "dot.radiowaves.up.forward")
                        .foregroundStyle(.orange)
                }
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "dot.radiowaves.up.forward")
                    .foregroundStyle(.orange)
            }
        }
    }
}

enum SidebarItem: Hashable {
    case allArticles
    case unread
    case starred
    case folder(FeedFolder)
    case feed(Feed)
}

#Preview("Sidebar (Split)") {
    NavigationStack {
        SidebarView(selectedItem: .constant(.allArticles))
    }
}

#Preview("Feed Row") {
    List {
        FeedRowView(feed: PreviewFixtures.feed)
    }
}
