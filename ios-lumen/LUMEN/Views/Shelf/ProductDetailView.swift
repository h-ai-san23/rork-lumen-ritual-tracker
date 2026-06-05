//
//  ProductDetailView.swift
//  LUMEN
//
//  Product detail: usage, cost-per-use, expiry, running-low, notes, reorder.
//

import SwiftUI
import SwiftData

struct ProductDetailView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var product: Product

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.l) {
                    hero
                    statsRow
                    expiryCard
                    lowToggle
                    notesCard
                    if !product.reorderUrl.isEmpty, let url = URL(string: product.reorderUrl) {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "cart.fill")
                                Text("Reorder").font(.ui(16, .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .foregroundStyle(palette.accent)
                            .padding(Space.l)
                            .frame(maxWidth: .infinity)
                            .background(palette.surface1)
                            .clipShape(.rect(cornerRadius: Radius.button))
                            .overlay(RoundedRectangle(cornerRadius: Radius.button).strokeBorder(palette.hairline, lineWidth: 1))
                        }
                    }
                    Button(role: .destructive) {
                        context.delete(product)
                        try? context.save()
                        dismiss()
                    } label: {
                        Text("Remove from shelf").font(.ui(15, .medium)).foregroundStyle(.red.opacity(0.85))
                            .frame(maxWidth: .infinity).padding(.vertical, Space.m)
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(Space.l)
            }
            .background(LumenBackground())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { try? context.save(); dismiss() }.foregroundStyle(palette.accent)
                }
            }
        }
        .tint(palette.accent)
    }

    private var hero: some View {
        VStack(spacing: Space.m) {
            ProductThumb(product: product, domain: product.domain, size: 110)
            VStack(spacing: 4) {
                Text(product.name).font(.serif(26, .semibold)).foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.center)
                Text(product.brand).font(.ui(15)).foregroundStyle(palette.textSecondary)
                Pill(text: product.domain.title, systemImage: product.domain.symbol).padding(.top, 4)
            }
        }
        .padding(.top, Space.s)
    }

    private var statsRow: some View {
        HStack(spacing: Space.m) {
            statCard("\(product.usageCount)", "Uses")
            statCard(product.cost > 0 ? String(format: "$%.2f", product.costPerUse) : "—", "Cost / use")
            statCard(product.cost > 0 ? String(format: "$%.0f", product.cost) : "—", "Paid")
        }
    }

    private func statCard(_ value: String, _ label: String) -> some View {
        VStack(spacing: 6) {
            Text(value).font(.serif(22, .semibold)).foregroundStyle(palette.textPrimary)
            Text(label).font(.ui(11, .medium)).foregroundStyle(palette.textSecondary).tracking(0.5).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.l)
        .background(palette.surface1)
        .clipShape(.rect(cornerRadius: Radius.tile))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(palette.hairline, lineWidth: 1))
    }

    private var expiryCard: some View {
        LumenCard {
            VStack(alignment: .leading, spacing: Space.s) {
                HStack {
                    Text("Opened").font(.ui(14)).foregroundStyle(palette.textSecondary)
                    Spacer()
                    Text(product.openedDate ?? Date(), format: .dateTime.month().day().year())
                        .font(.ui(14, .medium)).foregroundStyle(palette.textPrimary)
                }
                Hairline()
                HStack {
                    Text("Expires").font(.ui(14)).foregroundStyle(palette.textSecondary)
                    Spacer()
                    if let exp = product.expiryDate {
                        Text(exp, format: .dateTime.month().day().year())
                            .font(.ui(14, .medium))
                            .foregroundStyle(product.isExpiringSoon ? palette.goldDark : palette.textPrimary)
                    } else { Text("—").foregroundStyle(palette.textSecondary) }
                }
            }
        }
    }

    private var lowToggle: some View {
        Toggle(isOn: $product.lowFlag) {
            Label("Running low", systemImage: "drop.degreesign")
                .font(.ui(15, .medium)).foregroundStyle(palette.textPrimary)
        }
        .tint(palette.accent)
        .padding(Space.l)
        .background(palette.surface1)
        .clipShape(.rect(cornerRadius: Radius.tile))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(palette.hairline, lineWidth: 1))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text("NOTES").font(.ui(11, .semibold)).tracking(0.6).foregroundStyle(palette.textSecondary)
            TextField("Add a note…", text: $product.notes, axis: .vertical)
                .font(.ui(15)).foregroundStyle(palette.textPrimary)
                .lineLimit(3...6)
                .padding(Space.m)
                .background(palette.surface1)
                .clipShape(.rect(cornerRadius: Radius.button))
                .overlay(RoundedRectangle(cornerRadius: Radius.button).strokeBorder(palette.hairline, lineWidth: 1))
        }
    }
}
