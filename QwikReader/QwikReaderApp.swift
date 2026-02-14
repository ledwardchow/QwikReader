import SwiftUI

@main
struct QwikReaderApp: App {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some Scene {
        WindowGroup {
            AdaptiveContentView()
        }
    }
}

struct AdaptiveContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var feedManager = FeedManager.shared

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                ContentView()
            } else {
                CompactContentView()
            }
        }
        .task {
            if !ProcessInfo.isRunningForPreviews {
                await feedManager.refreshAllFeeds()
            }
        }
    }
}

#Preview {
    AdaptiveContentView()
}
