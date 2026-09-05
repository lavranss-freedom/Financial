import SwiftUI

@main
struct PersonalOverviewApp: App {
    @StateObject private var store = AppDataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .background(AppTheme.navy.ignoresSafeArea())
        }
    }
}
