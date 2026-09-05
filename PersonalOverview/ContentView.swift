import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: AppDataStore

    var body: some View {
        Group {
            if store.isUnlocked {
                MainTabView()
            } else {
                PinGateView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
