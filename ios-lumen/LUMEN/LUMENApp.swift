//
//  LUMENApp.swift
//  LUMEN
//
//  Created by Rork on June 3, 2026.
//

import SwiftUI
import SwiftData

@main
struct LUMENApp: App {
    @State private var authManager = AuthManager()

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
