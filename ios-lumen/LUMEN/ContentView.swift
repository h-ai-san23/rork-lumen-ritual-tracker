//
//  ContentView.swift
//  LUMEN
//
//  Root: bootstraps user state, gates onboarding, injects theme + engine,
//  and hosts the tab bar with the global celebration overlay.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [UserState]

    @State private var engine: RitualEngine?
    @State private var didReconcile = false

    private var user: UserState? { users.first }

    var body: some View {
        Group {
            if let user, let engine {
                let palette = Palette(isDark: user.isDark)
                ZStack {
                    if user.onboardingComplete {
                        RootTabView(user: user)
                            .overlay(CelebrationOverlay(engine: engine))
                    } else {
                        OnboardingView(user: user) {}
                    }
                }
                .environment(engine)
                .environment(\.palette, palette)
                .preferredColorScheme(user.isDark ? .dark : .light)
                .tint(palette.accent)
                .task {
                    guard !didReconcile else { return }
                    didReconcile = true
                    if user.onboardingComplete {
                        engine.reconcile(user: user)
                        engine.evaluateMedals(user: user)
                    }
                }
            } else {
                Color(hex: 0x0D0D0F).ignoresSafeArea()
                    .onAppear(perform: bootstrap)
            }
        }
        .onChange(of: users.count) { _, _ in ensureEngine() }
        .onAppear(perform: ensureEngine)
    }

    private func bootstrap() {
        if users.isEmpty {
            let state = UserState()
            context.insert(state)
            try? context.save()
        }
        ensureEngine()
    }

    private func ensureEngine() {
        if engine == nil { engine = RitualEngine(context: context) }
    }
}

struct RootTabView: View {
    @Environment(\.palette) private var palette
    let user: UserState

    init(user: UserState) {
        self.user = user
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Palette(isDark: user.isDark).surface1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.and.horizon.fill") { TodayView(user: user) }
            Tab("Shelf", systemImage: "square.grid.2x2.fill") { ShelfView(user: user) }
            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") { ProgressTabView(user: user) }
            Tab("Awards", systemImage: "rosette") { AchievementsView(user: user) }
            Tab("Profile", systemImage: "person.fill") { ProfileView(user: user) }
        }
        .tint(palette.accent)
    }
}
