import SwiftUI
import SwiftData

@main
struct JudesAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [StoryBook.self, TimedWord.self])
    }
}
