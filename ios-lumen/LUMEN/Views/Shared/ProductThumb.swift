//
//  ProductThumb.swift
//  LUMEN
//
//  A small product thumbnail used in step rows and the shelf.
//

import SwiftUI

struct ProductThumb: View {
    @Environment(\.palette) private var palette
    var product: Product?
    var domain: Domain
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(palette.surface2)
            if let data = product?.imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            } else {
                Image(systemName: domain.symbol)
                    .font(.system(size: size * 0.36))
                    .foregroundStyle(palette.accent.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: size * 0.28))
        .overlay(RoundedRectangle(cornerRadius: size * 0.28).strokeBorder(palette.hairline, lineWidth: 1))
    }
}
