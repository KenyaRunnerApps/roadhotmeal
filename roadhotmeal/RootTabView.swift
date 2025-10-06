//
//  RootTabView.swift
//  RoadHotMeal
//
//  Main tab bar for "Road: Hot Meal"
//

import SwiftUI

struct RootTabView: View {
    @Environment(\.appTheme) private var theme

    enum Tab: Hashable {
        case today, history, settings
    }

    @State private var selection: Tab = .today

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { TodayScreen() }   // <- можно оставить, если хочешь per-tab стеки
                .tabItem { Label("Today", systemImage: "flame.fill") }
                .tag(Tab.today)

            NavigationStack { JournalScreen() }
                .tabItem { Label("Journal", systemImage: "text.bubble.fill") }
                .tag(Tab.history) // 

            NavigationStack { SettingsScreen() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
        .accentColor(theme.tabBarTint)
        .background(theme.tabBarBackground.ignoresSafeArea())
    }
}

#Preview {
    RootTabView()
        .environmentObject(DataStore.shared)
        .environment(\.appTheme, ThemeManager.shared)
}
