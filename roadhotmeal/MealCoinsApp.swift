//
//  MealCoinsApp.swift
//  RoadHotMeal
//
//  Entry point for "Road: Hot Meal"
//

import SwiftUI

@main
struct MealCoinsApp: App {


    @StateObject private var store   = DataStore.shared
    private let theme                = ThemeManager.shared
    private let haptics              = HapticsManager.shared
    private let dateProvider         = DateProvider()

    @Environment(\.scenePhase) private var scenePhase

    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    final class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_ application: UIApplication,
                         supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
            if OrientationGate.allowAll {
                return [.portrait, .landscapeLeft, .landscapeRight]
            } else {
                return [.portrait]
            }
        }
    }
    
    init() {
        // Базовая настройка внешнего вида навигации/таббара (синхронизируется с темой в рантайме)
        NotificationCenter.default.post(name: Notification.Name("art.icon.loading.start"), object: nil)
        IconSettings.shared.attach()
    }
    
    var body: some Scene {
        WindowGroup {
            TabSettingsView{
                
                AppRootView()
                    .environmentObject(store)
                    .environment(\.appTheme, ThemeManager.shared) //
            }
            
            .onAppear {
                OrientationGate.allowAll = false
            }
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
