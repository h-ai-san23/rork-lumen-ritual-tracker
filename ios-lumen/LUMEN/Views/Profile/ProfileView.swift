//
//  ProfileView.swift
//  LUMEN
//
//  Profile & settings: theme, reminders, advisor, subscription, export.
//

import SwiftUI
import SwiftData
import AuthenticationServices

struct ProfileView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(AuthManager.self) private var auth
    @Bindable var user: UserState

    @Query private var products: [Product]
    @Query private var logs: [DayLog]
    @Environment(RitualEngine.self) private var engine

    @State private var showPaywall = false
    @State private var showAdvisor = false
    @State private var showEditRitual = false
    @State private var showEditGoals = false
    @State private var showSignIn = false
    @State private var pdfURL: URL?

    private var perfectDays: Int { logs.filter { engine.completion(for: $0) >= 1 }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                LumenBackground()
                ScrollView {
                    VStack(spacing: Space.l) {
                        profileHeader
                        if !user.isPremium { goldUpsell }
                        advisorRow
                        ritualEditing
                        ritualSettings
                        appearance
                        dataSection
                        subscriptionSection
                        Text("LUMEN · Built with care.")
                            .font(.ui(12)).foregroundStyle(palette.textSecondary)
                            .padding(.top, Space.m)
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showPaywall) { PaywallView(user: user) }
            .sheet(isPresented: $showAdvisor) { AdvisorView(user: user) }
            .sheet(isPresented: $showEditRitual) { EditRitualView() }
            .sheet(isPresented: $showEditGoals) { EditGoalsView(user: user) }
            .sheet(isPresented: $showSignIn) { SignInSheet() }
            .sheet(item: Binding(get: { pdfURL.map { IdentifiableURL(url: $0) } }, set: { pdfURL = $0?.url })) { wrapper in
                ShareSheet(items: [wrapper.url])
            }
        }
        .tint(palette.accent)
    }

    private var profileHeader: some View {
        LumenCard {
            HStack(spacing: Space.l) {
                ZStack {
                    Circle().fill(palette.gold).frame(width: 60, height: 60)
                    Image(systemName: user.rank.symbol).font(.system(size: 26)).foregroundStyle(Color(hex: 0x1A1306))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your Practice").font(.serif(22, .semibold)).foregroundStyle(palette.textPrimary)
                    Text("\(user.rank.rawValue) · \(user.xp) XP").font(.ui(14)).foregroundStyle(palette.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var goldUpsell: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: Space.m) {
                Image(systemName: "crown.fill").font(.ui(20)).foregroundStyle(Color(hex: 0x1A1306))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to LUMEN Gold").font(.ui(16, .bold)).foregroundStyle(Color(hex: 0x1A1306)).lineLimit(1).minimumScaleFactor(0.8)
                    Text("Unlimited everything · from $0.92/mo").font(.ui(12)).foregroundStyle(Color(hex: 0x1A1306).opacity(0.7)).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.ui(14, .bold)).foregroundStyle(Color(hex: 0x1A1306))
            }
            .padding(Space.l)
            .background(palette.gold)
            .clipShape(.rect(cornerRadius: Radius.card))
            .shadow(color: palette.goldDark.opacity(0.4), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var advisorRow: some View {
        Button { showAdvisor = true } label: {
            settingRow(symbol: "sparkles", title: "AI Advisor",
                       subtitle: user.isPremium ? "Unlimited" : "\(max(0, 3 - user.advisorQuestionsThisMonth)) free left this month",
                       accessory: "chevron.right")
        }
        .buttonStyle(.plain)
    }

    private var ritualEditing: some View {
        settingsGroup("Your ritual") {
            Button { showEditRitual = true } label: {
                editRow(symbol: "slider.horizontal.3", title: "Edit ritual steps", subtitle: "Revise, reorder, add or remove AM/PM steps")
            }
            .buttonStyle(.plain)
            Hairline()
            Button { showEditGoals = true } label: {
                editRow(symbol: "target", title: "Goals & rituals", subtitle: "Domains, sleep goal, and health habits")
            }
            .buttonStyle(.plain)
        }
    }

    private func editRow(symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Space.m) {
            Image(systemName: symbol).font(.ui(16)).foregroundStyle(palette.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ui(15, .medium)).foregroundStyle(palette.textPrimary).lineLimit(1)
                Text(subtitle).font(.ui(12)).foregroundStyle(palette.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.ui(13)).foregroundStyle(palette.textSecondary)
        }
    }

    private var ritualSettings: some View {
        settingsGroup("Reminders") {
            Toggle(isOn: $user.remindersEnabled) {
                Label("Daily reminders", systemImage: "bell.fill").font(.ui(15)).foregroundStyle(palette.textPrimary)
            }
            .tint(palette.accent)
            .onChange(of: user.remindersEnabled) { _, on in reschedule(enabled: on) }

            Hairline()
            timeRow("Wake", symbol: "sun.max.fill", selection: $user.wakeTime)
            Hairline()
            timeRow("Wind down", symbol: "moon.fill", selection: $user.windDownTime)
        }
    }

    private func timeRow(_ title: String, symbol: String, selection: Binding<Date>) -> some View {
        HStack {
            Label(title, systemImage: symbol).font(.ui(15)).foregroundStyle(palette.textPrimary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden().tint(palette.accent)
                .onChange(of: selection.wrappedValue) { _, _ in reschedule(enabled: user.remindersEnabled) }
        }
    }

    private var appearance: some View {
        settingsGroup("Appearance") {
            Toggle(isOn: $user.isDark) {
                Label("Dark theme", systemImage: user.isDark ? "moon.fill" : "sun.max.fill")
                    .font(.ui(15)).foregroundStyle(palette.textPrimary)
            }
            .tint(palette.accent)
            if !user.isPremium {
                Hairline()
                Button { showPaywall = true } label: {
                    HStack {
                        Label("Premium themes", systemImage: "paintpalette.fill").font(.ui(15)).foregroundStyle(palette.textPrimary)
                        Spacer()
                        LockBadge()
                    }
                }
            }
        }
    }

    private var dataSection: some View {
        settingsGroup("Your data") {
            Button { exportPDF() } label: {
                HStack {
                    Label("Export report (PDF)", systemImage: "doc.richtext").font(.ui(15)).foregroundStyle(palette.textPrimary)
                    Spacer()
                    if !user.isPremium { LockBadge() } else { Image(systemName: "square.and.arrow.up").foregroundStyle(palette.textSecondary) }
                }
            }
            Hairline()
            if let account = auth.user {
                HStack(spacing: Space.m) {
                    Image(systemName: "person.crop.circle.fill").font(.ui(16)).foregroundStyle(palette.accent).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name ?? "Account").font(.ui(15, .medium)).foregroundStyle(palette.textPrimary).lineLimit(1)
                        Text(account.email).font(.ui(12)).foregroundStyle(palette.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer()
                    Button("Sign out") { Task { await auth.signOut() } }
                        .font(.ui(13, .semibold)).foregroundStyle(palette.textSecondary)
                }
            } else {
                Button { showSignIn = true } label: {
                    HStack(spacing: Space.m) {
                        Image(systemName: "person.crop.circle.badge.plus").font(.ui(16)).foregroundStyle(palette.accent).frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create account or sign in").font(.ui(15, .medium)).foregroundStyle(palette.textPrimary).lineLimit(1)
                            Text("Save and sync your progress").font(.ui(12)).foregroundStyle(palette.textSecondary).lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.ui(13)).foregroundStyle(palette.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var subscriptionSection: some View {
        settingsGroup("Subscription") {
            HStack {
                Label("Plan", systemImage: "crown.fill").font(.ui(15)).foregroundStyle(palette.textPrimary)
                Spacer()
                Text(user.isPremium ? "LUMEN Gold" : "Free").font(.ui(15, .medium)).foregroundStyle(user.isPremium ? palette.accent : palette.textSecondary)
            }
            if user.isPremium {
                Hairline()
                Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                    HStack {
                        Text("Manage or cancel").font(.ui(15)).foregroundStyle(palette.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right").foregroundStyle(palette.textSecondary)
                    }
                }
            } else {
                Hairline()
                Button { showPaywall = true } label: {
                    HStack {
                        Text("See plans").font(.ui(15)).foregroundStyle(palette.accent)
                        Spacer()
                        Image(systemName: "chevron.right").font(.ui(13)).foregroundStyle(palette.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title.uppercased()).font(.ui(11, .semibold)).tracking(0.6).foregroundStyle(palette.textSecondary)
                .padding(.leading, Space.s)
            VStack(spacing: Space.m) { content() }
                .padding(Space.l)
                .background(palette.surface1)
                .clipShape(.rect(cornerRadius: Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(palette.hairline, lineWidth: 1))
        }
    }

    private func settingRow(symbol: String, title: String, subtitle: String, accessory: String?) -> some View {
        HStack(spacing: Space.m) {
            Image(systemName: symbol).font(.ui(16)).foregroundStyle(palette.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.ui(16, .medium)).foregroundStyle(palette.textPrimary).lineLimit(1)
                Text(subtitle).font(.ui(12)).foregroundStyle(palette.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer()
            if let accessory { Image(systemName: accessory).font(.ui(13)).foregroundStyle(palette.textSecondary) }
        }
        .padding(Space.l)
        .background(palette.surface1)
        .clipShape(.rect(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(palette.hairline, lineWidth: 1))
    }

    private func reschedule(enabled: Bool) {
        try? context.save()
        NotificationManager.scheduleReminders(wake: user.wakeTime, windDown: user.windDownTime, enabled: enabled)
    }

    private func exportPDF() {
        guard user.isPremium else { showPaywall = true; return }
        pdfURL = PDFExport.makeReport(user: user, productCount: products.count, perfectDays: perfectDays)
    }
}

/// Standalone sign-in sheet reachable from Profile for users who skipped
/// account creation during onboarding.
private struct SignInSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var auth

    var body: some View {
        @Bindable var auth = auth
        ZStack {
            LumenBackground()
            VStack(spacing: Space.xl) {
                Spacer()
                ZStack {
                    Circle().fill(palette.gold.opacity(0.18)).frame(width: 92, height: 92)
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 40)).foregroundStyle(palette.gold)
                }
                VStack(spacing: Space.s) {
                    Text("Save your progress").font(.serif(28, .semibold)).foregroundStyle(palette.textPrimary)
                    Text("Create an account to keep your rituals and streaks safe across devices.")
                        .font(.ui(15)).foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center).lineSpacing(3).padding(.horizontal, Space.l)
                }

                VStack(spacing: Space.m) {
                    SignInWithAppleButton(.signUp) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { _ in
                        Task { await auth.signIn(provider: "apple") }
                    }
                    .signInWithAppleButtonStyle(palette.isDark ? .white : .black)
                    .frame(height: 52)
                    .clipShape(.rect(cornerRadius: Radius.tile))
                    .disabled(auth.isSigningIn)

                    Button {
                        Task { await auth.signIn(provider: "google") }
                    } label: {
                        HStack(spacing: Space.s) {
                            Image(systemName: "globe")
                            Text("Continue with Google").font(.ui(17, .semibold))
                        }
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(palette.surface1)
                        .clipShape(.rect(cornerRadius: Radius.tile))
                        .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(palette.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(auth.isSigningIn)

                    if auth.isSigningIn { ProgressView().tint(palette.accent) }
                }
                .padding(.horizontal, Space.xl)
                Spacer()
                Button("Not now") { dismiss() }
                    .font(.ui(15)).foregroundStyle(palette.textSecondary)
            }
            .padding(.vertical, Space.xl)
        }
        .alert("Sign in failed", isPresented: $auth.showError) {
            Button("OK") {}
        } message: { Text(auth.errorMessage) }
        .onChange(of: auth.user?.id) { _, id in
            if id != nil { dismiss() }
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
