//
//  EditRitualView.swift
//  LUMEN
//
//  Revise the AM/PM ritual: edit, reorder, add, and remove steps, and edit
//  the linked product for each one.
//

import SwiftUI
import SwiftData

struct EditRitualView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \RitualStep.order) private var steps: [RitualStep]
    @Query private var products: [Product]

    @State private var ritual: RitualTime = .am
    @State private var editorStep: RitualStep?

    private var current: [RitualStep] { steps.filter { $0.ritual == ritual } }

    var body: some View {
        NavigationStack {
            ZStack {
                LumenBackground()
                VStack(spacing: Space.m) {
                    ritualPicker
                    if current.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
                .padding(.top, Space.s)
            }
            .navigationTitle("Edit Ritual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { save(); dismiss() }.foregroundStyle(palette.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Space.m) {
                        EditButton().foregroundStyle(palette.accent)
                        Button { addStep() } label: {
                            Image(systemName: "plus").font(.ui(16, .semibold)).foregroundStyle(palette.accent)
                        }
                    }
                }
            }
            .sheet(item: $editorStep) { step in
                StepEditorView(step: step, products: products)
            }
        }
        .tint(palette.accent)
    }

    private var ritualPicker: some View {
        Picker("Ritual", selection: $ritual) {
            ForEach(RitualTime.allCases) { r in Text(r.title).tag(r) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Space.l)
    }

    private var list: some View {
        List {
            Section {
                ForEach(current) { step in
                    Button { editorStep = step } label: { row(step) }
                        .listRowBackground(palette.surface1)
                        .listRowSeparatorTint(palette.hairline)
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            } footer: {
                Text("Drag to reorder · swipe to remove. Tap a step to edit its how-to, timer, and product.")
                    .font(.ui(12)).foregroundStyle(palette.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func row(_ step: RitualStep) -> some View {
        HStack(spacing: Space.m) {
            Image(systemName: step.domain.symbol)
                .font(.ui(15)).foregroundStyle(palette.accent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(palette.surface2))
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title.isEmpty ? "Untitled step" : step.title)
                    .font(.ui(16, .medium)).foregroundStyle(palette.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(step.domain.title)
                    if step.timerSeconds > 0 {
                        Text("· \(step.timerSeconds)s")
                    }
                }
                .font(.ui(12)).foregroundStyle(palette.textSecondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.ui(13)).foregroundStyle(palette.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: Space.m) {
            Spacer()
            Image(systemName: ritual.symbol).font(.system(size: 40)).foregroundStyle(palette.accent.opacity(0.7))
            Text("No steps yet")
                .font(.serif(22, .medium)).foregroundStyle(palette.textPrimary)
            Text("Add your first \(ritual.title.lowercased()) step.")
                .font(.ui(14)).foregroundStyle(palette.textSecondary)
            GoldButton(title: "Add a step", systemImage: "plus") { addStep() }
                .frame(maxWidth: 220).padding(.top, Space.s)
            Spacer()
        }
        .padding(Space.l)
    }

    // MARK: - Mutations

    private func addStep() {
        let order = (current.map(\.order).max() ?? -1) + 1
        let step = RitualStep(ritual: ritual, domain: .skin, title: "", howTo: "", order: order)
        context.insert(step)
        editorStep = step
    }

    private func move(_ offsets: IndexSet, _ destination: Int) {
        var reordered = current
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, step) in reordered.enumerated() { step.order = index }
        try? context.save()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func delete(_ offsets: IndexSet) {
        for index in offsets { context.delete(current[index]) }
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func save() { try? context.save() }
}

// MARK: - Step editor

private struct StepEditorView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var step: RitualStep
    let products: [Product]

    @State private var timerMinutes: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.l) {
                    field("Step name", text: $step.title, placeholder: "Cleanse")

                    labeled("Domain") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Space.s) {
                                ForEach(Domain.allCases) { d in
                                    Button { step.domain = d } label: {
                                        Pill(text: d.title, systemImage: d.symbol, selected: step.domain == d)
                                    }
                                }
                            }
                        }
                        .scrollClipDisabled()
                    }

                    labeled("How-to") {
                        TextField("Short guidance for this step…", text: $step.howTo, axis: .vertical)
                            .font(.ui(16)).foregroundStyle(palette.textPrimary)
                            .lineLimit(3...6)
                            .padding(Space.m)
                            .background(palette.surface1)
                            .clipShape(.rect(cornerRadius: Radius.button))
                            .overlay(RoundedRectangle(cornerRadius: Radius.button).strokeBorder(palette.hairline, lineWidth: 1))
                    }

                    labeled(timerMinutes > 0 ? "Timer — \(Int(timerMinutes * 60))s" : "Timer — none") {
                        Slider(value: $timerMinutes, in: 0...10, step: 0.25)
                            .tint(palette.accent)
                            .onChange(of: timerMinutes) { _, v in step.timerSeconds = Int(v * 60) }
                    }

                    labeled("Linked product") {
                        productPicker
                    }
                }
                .padding(Space.l)
            }
            .background(LumenBackground())
            .navigationTitle("Edit Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { try? context.save(); dismiss() }.foregroundStyle(palette.accent)
                }
            }
            .onAppear { timerMinutes = Double(step.timerSeconds) / 60.0 }
        }
        .tint(palette.accent)
    }

    private var productPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                Button { step.productID = nil } label: {
                    Pill(text: "None", selected: step.productID == nil)
                }
                ForEach(products) { product in
                    Button { step.productID = product.id } label: {
                        Pill(text: product.name, selected: step.productID == product.id)
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        labeled(label) {
            TextField(placeholder, text: text)
                .font(.ui(16)).foregroundStyle(palette.textPrimary)
                .padding(Space.m)
                .background(palette.surface1)
                .clipShape(.rect(cornerRadius: Radius.button))
                .overlay(RoundedRectangle(cornerRadius: Radius.button).strokeBorder(palette.hairline, lineWidth: 1))
        }
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(label.uppercased())
                .font(.ui(11, .semibold)).tracking(0.6).foregroundStyle(palette.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
