//
//  ShelfView.swift
//  LUMEN
//
//  Product inventory: a grid of tiles, filter chips, and the add flow.
//

import SwiftUI
import SwiftData

struct ShelfView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    let user: UserState

    @Query(sort: \Product.createdAt, order: .reverse) private var products: [Product]
    @State private var filter: Domain?
    @State private var needsAttentionOnly = false
    @State private var showAdd = false
    @State private var showPaywall = false
    @State private var selected: Product?

    private let columns = [GridItem(.flexible(), spacing: Space.m), GridItem(.flexible(), spacing: Space.m)]

    private var filtered: [Product] {
        products.filter { p in
            (filter == nil || p.domain == filter) && (!needsAttentionOnly || p.needsAttention)
        }
    }

    /// Free members can track up to 6 products; Gold is unlimited.
    static let freeProductLimit = 6
    private var freeLimitReached: Bool { !user.isPremium && products.count >= Self.freeProductLimit }

    var body: some View {
        NavigationStack {
            ZStack {
                LumenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.l) {
                        filterRow
                        if products.isEmpty {
                            emptyState
                        } else {
                            countLine
                            LazyVGrid(columns: columns, spacing: Space.m) {
                                ForEach(filtered) { product in
                                    ProductTile(product: product)
                                        .onTapGesture { selected = product }
                                }
                            }
                        }
                        Color.clear.frame(height: 40)
                    }
                    .padding(.horizontal, Space.l)
                    .padding(.top, Space.s)
                }
            }
            .navigationTitle("Shelf")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if freeLimitReached { showPaywall = true } else { showAdd = true }
                    } label: {
                        Image(systemName: "plus").font(.ui(16, .semibold)).foregroundStyle(palette.accent)
                    }
                }
            }
            .sheet(isPresented: $showAdd) { AddProductSheet() }
            .sheet(item: $selected) { ProductDetailView(product: $0) }
            .sheet(isPresented: $showPaywall) { PaywallView(user: user) }
        }
        .tint(palette.accent)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                Button { withAnimation(.snappy) { filter = nil; needsAttentionOnly = false } } label: {
                    Pill(text: "All", selected: filter == nil && !needsAttentionOnly)
                }
                Button { withAnimation(.snappy) { needsAttentionOnly.toggle(); filter = nil } } label: {
                    Pill(text: "Needs attention", systemImage: "exclamationmark.circle", selected: needsAttentionOnly)
                }
                ForEach(Domain.allCases) { d in
                    Button { withAnimation(.snappy) { filter = (filter == d ? nil : d); needsAttentionOnly = false } } label: {
                        Pill(text: d.title, systemImage: d.symbol, selected: filter == d)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var countLine: some View {
        HStack {
            Text("\(products.count) product\(products.count == 1 ? "" : "s")")
                .font(.ui(13, .medium)).foregroundStyle(palette.textSecondary)
            if !user.isPremium {
                Text("· \(max(0, Self.freeProductLimit - products.count)) free slots left")
                    .font(.ui(13)).foregroundStyle(palette.accent).lineLimit(1)
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Space.m) {
            Image(systemName: "books.vertical")
                .font(.system(size: 44)).foregroundStyle(palette.accent.opacity(0.7))
            Text("Your shelf is empty")
                .font(.serif(22, .medium)).foregroundStyle(palette.textPrimary)
            Text("Add the products you already use to track usage, cost-per-use, and expiry.")
                .font(.ui(15)).foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
            GoldButton(title: "Add a product", systemImage: "plus") { showAdd = true }
                .frame(maxWidth: 240)
                .padding(.top, Space.s)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

struct ProductTile: View {
    @Environment(\.palette) private var palette
    let product: Product

    var body: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: Radius.tile).fill(palette.surface2)
                    .frame(height: 120)
                    .overlay {
                        if let data = product.imageData, let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                        } else {
                            Image(systemName: product.domain.symbol)
                                .font(.system(size: 34)).foregroundStyle(palette.accent.opacity(0.8))
                        }
                    }
                    .clipShape(.rect(cornerRadius: Radius.tile))
                if product.needsAttention {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.ui(14)).foregroundStyle(palette.goldDark)
                        .padding(8)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(.ui(15, .semibold)).foregroundStyle(palette.textPrimary).lineLimit(1).minimumScaleFactor(0.85)
                Text(product.brand.isEmpty ? product.domain.title : product.brand)
                    .font(.ui(12)).foregroundStyle(palette.textSecondary).lineLimit(1)
            }
        }
        .padding(Space.s)
        .background(palette.surface1)
        .clipShape(.rect(cornerRadius: Radius.tile))
        .overlay(RoundedRectangle(cornerRadius: Radius.tile).strokeBorder(palette.hairline, lineWidth: 1))
    }
}
