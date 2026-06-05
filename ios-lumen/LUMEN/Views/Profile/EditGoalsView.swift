//
//  EditGoalsView.swift
//  LUMEN
//
//  Revise the rituals you're building, your goals, and your sleep target.
//

import SwiftUI
import SwiftData

struct EditGoalsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var user: UserState

    private let habitOptions = ["Hydration", "Supplements", "Movement", "Mindfulness", "Less screen time"]

    var body: some View {
        NavigationStack {
            ZStack {
                LumenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.l) {
                        domainsSection
                        sleepSection
                        habitsSection
                        Color.clear.frame(height: 30)
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                }
            }
            .navigationTitle("Goals & Rituals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { try? context.save(); dismiss() }.foregroundStyle(palette.accent)
                }
            }
        }
        .tint(palette.accent)
    }

    private var domainsSection: some View {
        group("Rituals you're building") {
            VStack(spacing: Space.s) {
                ForEach(Domain.allCases) { domain in
                    let on = user.selectedDomains.contains(domain.rawValue)
                    Button { toggleDomain(domain) } label: {
                        HStack(spacing: Space.m) {
                            Image(systemName: domain.symbol)
                                .font(.ui(15))
                                .foregroundStyle(on ? Color(hex: 0x1A1306) : palette.accent)
                                .frame(width: 38, height: 38)
                                .background {
                                    if on { Circle().fill(palette.gold) }
                                    else { Circle().strokeBorder(palette.hairline, lineWidth: 1) }
                                }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(domain.title).font(.ui(16, .semibold)).foregroundStyle(palette.textPrimary).lineLimit(1)
                                Text(domain.blurb).font(.ui(12)).foregroundStyle(palette.textSecondary).lineLimit(1).minimumScaleFactor(0.85)
                            }
                            Spacer()
                            Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(on ? palette.accent : palette.hairline)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sleepSection: some View {
        group("Nightly sleep goal") {
            VStack(spacing: Space.m) {
                Text(String(format: "%.1f hrs", user.sleepGoal))
                    .font(.serif(30, .semibold)).foregroundStyle(palette.textPrimary)
                Slider(value: $user.sleepGoal, in: 5...10, step: 0.5).tint(palette.accent)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var habitsSection: some View {
        group("Health habits") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Space.s)], alignment: .leading, spacing: Space.s) {
                ForEach(habitOptions, id: \.self) { habit in
                    let on = user.goals.contains(habit)
                    Button { toggleHabit(habit) } label: {
                        Text(habit)
                            .font(.ui(14, .medium))
                            .foregroundStyle(on ? Color(hex: 0x1A1306) : palette.textPrimary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                if on { Capsule().fill(palette.gold) }
                                else { Capsule().strokeBorder(palette.hairline, lineWidth: 1) }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title.uppercased()).font(.ui(11, .semibold)).tracking(0.6).foregroundStyle(palette.textSecondary)
                .padding(.leading, Space.s)
            content()
                .padding(Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surface1)
                .clipShape(.rect(cornerRadius: Radius.card))
                .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(palette.hairline, lineWidth: 1))
        }
    }

    private func toggleDomain(_ domain: Domain) {
        UISelectionFeedbackGenerator().selectionChanged()
        if let idx = user.selectedDomains.firstIndex(of: domain.rawValue) {
            guard user.selectedDomains.count > 1 else { return } // keep at least one
            user.selectedDomains.remove(at: idx)
        } else {
            user.selectedDomains.append(domain.rawValue)
        }
    }

    private func toggleHabit(_ habit: String) {
        UISelectionFeedbackGenerator().selectionChanged()
        if let idx = user.goals.firstIndex(of: habit) {
            user.goals.remove(at: idx)
        } else {
            user.goals.append(habit)
        }
    }
}
