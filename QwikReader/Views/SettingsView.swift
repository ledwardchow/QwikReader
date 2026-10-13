import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var offlineManager = OfflineManager.shared
    @ObservedObject var cloudKit = CloudKitManager.shared
    @ObservedObject var feedManager = FeedManager.shared
    @ObservedObject var readabilityExtractor = ReadabilityExtractor.shared

    @State private var showClearCacheConfirmation = false
    @State private var showClearOfflineConfirmation = false
    @State private var showClearReaderCacheConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                // Appearance
                Section {
                    Picker("Article Layout", selection: $themeManager.articleListLayout) {
                        ForEach(ArticleListLayout.allCases, id: \.self) { layout in
                            Label(layout.displayName, systemImage: layout.icon).tag(layout)
                        }
                    }

                    Picker("Reader Theme", selection: $themeManager.readerTheme) {
                        ForEach(ReaderTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }

                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(themeManager.readerFontSize))pt")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $themeManager.readerFontSize, in: 12...28, step: 1)
                } header: {
                    Text("Appearance")
                }

                // Sync
                Section {
                    HStack {
                        Label("iCloud Sync", systemImage: "icloud")
                        Spacer()
                        if cloudKit.iCloudAvailable {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        } else {
                            Label("Unavailable", systemImage: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }

                    Button {
                        Task { await feedManager.refreshAllFeeds() }
                    } label: {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Your feed subscriptions are stored in iCloud and sync across all your devices.")
                }

                // Offline
                Section {
                    Toggle("Auto-Cache Reading View", isOn: $themeManager.autoCacheReaderView)

                    if themeManager.autoCacheReaderView {
                        Stepper("Cache \(themeManager.autoCacheDays) \(themeManager.autoCacheDays == 1 ? "day" : "days") of articles", value: $themeManager.autoCacheDays, in: 1...14)
                    }

                    HStack {
                        Text("Offline Storage")
                        Spacer()
                        Text(offlineManager.offlineStorageSize())
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showClearOfflineConfirmation = true
                    } label: {
                        Label("Clear Offline Content", systemImage: "trash")
                    }

                    HStack {
                        Text("Reading View Cache")
                        Spacer()
                        Text(readabilityExtractor.cachedSizeString)
                            .foregroundStyle(.secondary)
                    }

                    Button(role: .destructive) {
                        showClearReaderCacheConfirmation = true
                    } label: {
                        Label("Clear Reading View Cache", systemImage: "doc.plaintext")
                    }
                } header: {
                    Text("Offline Reading")
                } footer: {
                    if themeManager.autoCacheReaderView {
                        Text("Articles from the last \(themeManager.autoCacheDays) \(themeManager.autoCacheDays == 1 ? "day" : "days") will be cached for offline reading when you refresh. Cached articles open in Reading View by default.")
                    }
                }

                // Cache
                Section {
                    Button(role: .destructive) {
                        showClearCacheConfirmation = true
                    } label: {
                        Label("Clear Image Cache", systemImage: "photo.on.rectangle.angled")
                    }
                } header: {
                    Text("Cache")
                }

                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Feeds")
                        Spacer()
                        Text("\(cloudKit.feeds.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Articles")
                        Spacer()
                        Text("\(feedManager.allArticles.count)")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear offline content?", isPresented: $showClearOfflineConfirmation) {
                Button("Clear All Offline Content", role: .destructive) {
                    offlineManager.clearAllOfflineContent()
                }
            } message: {
                Text("This will remove all downloaded articles. You can re-download them later.")
            }
            .confirmationDialog("Clear image cache?", isPresented: $showClearCacheConfirmation) {
                Button("Clear Cache", role: .destructive) {
                    ImageCache.shared.clearCache()
                }
            } message: {
                Text("Cached images will be re-downloaded as needed.")
            }
            .confirmationDialog("Clear reading view cache?", isPresented: $showClearReaderCacheConfirmation) {
                Button("Clear Reading View Cache", role: .destructive) {
                    readabilityExtractor.clearCache()
                }
            } message: {
                Text("Cached reading view content will be re-extracted as needed.")
            }
        }
    }
}

#Preview {
    SettingsView()
}
