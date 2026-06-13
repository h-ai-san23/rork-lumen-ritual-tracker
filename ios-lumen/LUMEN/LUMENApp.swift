//
//  LUMENApp.swift
//  LUMEN
//
//  Created by Rork on June 3, 2026.
//

import SwiftUI
import SwiftData
import RevenueCat

@main
struct LUMENApp: App {
    @State private var authManager = AuthManager()

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_TEST_API_KEY)
        #else
        Purchases.configure(withAPIKey: Config.EXPO_PUBLIC_REVENUECAT_IOS_API_KEY)
        #endif
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserState.self,
            Product.self,
            RitualStep.self,
            DayLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
