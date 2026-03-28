import SwiftUI

@main
struct RuneShelfApp: App {
    @StateObject private var store = RuneShelfStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .font(.runeStyle(.body))
                .environmentObject(store)
                .task {
                    await store.bootstrapIfNeeded()
                }
        }
    }
}
