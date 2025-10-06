//
//  MealCoinsApp.swift
//  RoadHotMeal
//
//  Entry point for "Road: Hot Meal"
//

import SwiftUI

@main
struct MealCoinsApp: App {

    // Синглтоны домена
    @StateObject private var store   = DataStore.shared
    private let theme                = ThemeManager.shared
    private let haptics              = HapticsManager.shared
    private let dateProvider         = DateProvider() // пригодится далее в VM/сервисах

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
                .environment(\.appTheme, ThemeManager.shared) // <- явная инъекция

            
        }
//        .onChange(of: scenePhase) { _, newPhase in
//            if newPhase == .active {
//
//                haptics.enableLocally()
//            }
//        }
//        
        
    }
}

/// Отдельная обёртка, чтобы синхронизировать тему с системной цветовой схемой.
private struct AppRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appTheme) private var theme

    var body: some View {
        RootTabView()
           
            .onAppear { theme.syncWithSystem(colorScheme) }
          
            .onChange(of: colorScheme) { _, new in
                theme.syncWithSystem(new)
            }
            .themedBackground()
        
        
    }
}
