//
//  AddProductSheet.swift
//  LUMEN
//
//  Add a product by photo or manual entry. Barcode scanning is available on
//  device via the camera.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddProductSheet: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var brand = ""
    @State private var domain: Domain = .skin
    @State private var pao = 12
    @State private var cost = ""
    @State private var reorderUrl = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var notes = ""
    @State private var isGenerating = false
    @State private var aiError: String?
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.l) {
                    photoPicker
                    aiActions
                    field("Name", text: $name, placeholder: "Vitamin C Serum")
                    field("Brand", text: $brand, placeholder: "Atelier")

                    labeled("Category") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Space.s) {
                                ForEach(Domain.allCases) { d in
                                    Button { domain = d } label: {
                                        Pill(text: d.title, systemImage: d.symbol, selected: domain == d)
                                    }
                                }
                            }
                        }
                        .scrollClipDisabled()
                    }

                    labeled("Period after opening — \(pao) months") {
                        Slider(value: Binding(get: { Double(pao) }, set: { pao = Int($0) }), in: 1...36, step: 1)
                            .tint(palette.accent)
                    }

                    field("Cost", text: $cost, placeholder: "0.00", keyboard: .decimalPad)
                    field("Reorder link", text: $reorderUrl, placeholder: "https://…", keyboard: .URL)

                    if !notes.isEmpty {
                        labeled("Notes") {
                            Text(notes).font(.ui(14)).foregroundStyle(palette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Space.m)
                                .background(palette.surface1)
                                .clipShape(.rect(cornerRadius: Radius.button))
                                .overlay(RoundedRectangle(cornerRadius: Radius.button).strokeBorder(palette.hairline, lineWidth: 1))
                        }
                    }

                    GoldButton(title: "Add to shelf") { save() }
                        .disabled(name.isEmpty)
                        .opacity(name.isEmpty ? 0.5 : 1)
                        .padding(.top, Space.s)
                }
                .padding(Space.l)
            }
            .background(LumenBackground())
            .navigationTitle("New Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(palette.textSecondary)
                }
            }
            .onChange(of: pickerItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { code in scanBarcode(code) }
            }
        }
        .tint(palette.accent)
    }

    private var aiActions: some View {
        VStack(spacing: Space.s) {
            HStack(spacing: Space.s) {
                Button { generateFromPhoto() } label: {
                    aiPill("sparkles", imageData == nil ? "Identify photo" : "Identify with AI")
                }
                .buttonStyle(.plain)
                .disabled(imageData == nil || isGenerating)
                .opacity(imageData == nil ? 0.5 : 1)

                Button { showScanner = true } label: {
                    aiPill("barcode.viewfinder", "Scan barcode")
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }
            if isGenerating {
                HStack(spacing: Space.s) {
                    ProgressView().tint(palette.accent)
                    Text("Identifying product…").font(.ui(13)).foregroundStyle(palette.textSecondary)
                }
            } else if let aiError {
                Text(aiError).font(.ui(12)).foregroundStyle(palette.goldDark)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            } else {
                Text("Take or pick a photo, or scan a barcode — AI fills in the details.")
                    .font(.ui(12)).foregroundStyle(palette.textSecondary.opacity(0.8))
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
        }
    }

    private func aiPill(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.ui(14, .semibold))
            Text(title).font(.ui(14, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(palette.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(palette.accent.opacity(0.12))
        .clipShape(.rect(cornerRadius: Radius.button))
        .overlay(RoundedRectangle(cornerRadius: Radius.button).strokeBorder(palette.accent.opacity(0.3), lineWidth: 1))
    }

    private func generateFromPhoto() {
        guard let data = imageData else { return }
        runAI { try await ProductAIService.identify(from: data) }
    }

    private func scanBarcode(_ code: String) {
        runAI { try await ProductAIService.identify(barcode: code) }
    }

    private func runAI(_ operation: @escaping () async throws -> ProductDraft) {
        aiError = nil
        isGenerating = true
        Task {
            do {
                let draft = try await operation()
                apply(draft)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                aiError = (error as? ProductAIError)?.errorDescription ?? "Couldn't identify the product."
            }
            isGenerating = false
        }
    }

    private func apply(_ draft: ProductDraft) {
        name = draft.name
        if !draft.brand.isEmpty { brand = draft.brand }
        domain = draft.domain
        pao = draft.paoMonths
        notes = draft.notes
        if let image = draft.imageData { imageData = image }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.card).fill(palette.surface1)
                    .frame(height: 160)
                    .overlay(RoundedRectangle(cornerRadius: Radius.card).strokeBorder(palette.hairline, lineWidth: 1))
                if let imageData, let ui = UIImage(data: imageData) {
                    Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill)
                        .frame(height: 160).clipShape(.rect(cornerRadius: Radius.card)).allowsHitTesting(false)
                } else {
                    VStack(spacing: Space.s) {
                        Image(systemName: "camera.fill").font(.system(size: 28)).foregroundStyle(palette.accent)
                        Text("Add a photo").font(.ui(14, .medium)).foregroundStyle(palette.textSecondary)
                        Text("Scan a barcode on device").font(.ui(11)).foregroundStyle(palette.textSecondary.opacity(0.7))
                    }
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        labeled(label) {
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.ui(16))
                .foregroundStyle(palette.textPrimary)
                .padding(Space.m)
                .background(palette.surface1)
                .clipShape(.rect(cornerRadius: Radius.button))
                .overlay(RoundedRectangle(cornerRadius: Radius.button).strokeBorder(palette.hairline, lineWidth: 1))
        }
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(label.uppercased())
                .font(.ui(11, .semibold)).tracking(0.6)
                .foregroundStyle(palette.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        let p = Product(name: name, brand: brand, domain: domain, openedDate: Date(),
                        paoMonths: pao, cost: Double(cost) ?? 0, notes: notes, reorderUrl: reorderUrl)
        p.imageData = imageData
        context.insert(p)
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
