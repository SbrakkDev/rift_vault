import SwiftUI

@main
struct RiftVaultApp: App {
    @StateObject private var store = RiftVaultStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    await store.bootstrapIfNeeded()
                }
        }
    }
}
