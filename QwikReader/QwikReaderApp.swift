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

    var body: some View {
        if horizontalSizeClass == .regular {
            ContentView()
        } else {
            CompactContentView()
        }
    }
}

#Preview {
    AdaptiveContentView()
}
