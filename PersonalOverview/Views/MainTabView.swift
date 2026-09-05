import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            StanceView()
                .tabItem { Label("Stance", systemImage: "chart.pie.fill") }
            BookView()
                .tabItem { Label("Book", systemImage: "book.closed.fill") }
            CandidatesView()
                .tabItem { Label("Candidates", systemImage: "list.bullet.rectangle") }
            AlertsView()
                .tabItem { Label("Alerts", systemImage: "bell.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(AppTheme.gold)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppTheme.navy)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
