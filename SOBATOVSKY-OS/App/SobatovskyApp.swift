import SwiftUI

@main
struct SobatovskyApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var focus = FocusEngine()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(focus)
        }
    }
}
