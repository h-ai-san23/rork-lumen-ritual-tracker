//
//  BarcodeLookupService.swift
//  LUMEN
//
//  Looks up a scanned barcode against free, open product databases so the
//  exact product (name, brand, photo, category) is identified rather than
//  guessed.
//
//  Accuracy strategy:
//   1. Normalise the code (strip non-digits, expand UPC-E → UPC-A).
//   2. Query several free, key-less databases CONCURRENTLY:
//        • Open Beauty Facts   — best for skincare / grooming
//        • Open Food Facts     — supplements, teas, drinks
//        • Open Products Facts — general goods
//        • UPCitemdb (trial)   — broad US retail coverage
//   3. Score every candidate by completeness + source relevance and return the
//      single best match, instead of trusting whichever database answers first.
//

import Foundation
import UIKit

/// Result of a successful barcode database lookup.
nonisolated struct BarcodeMatch: Sendable {
    var name: String
    var brand: String
    var domain: Domain
    var imageURL: String?
}

nonisolated enum BarcodeLookupService {
    /// Look up a barcode and return the best-matched product, or nil if no
    /// database recognises it. Never throws — callers fall back to AI.
    static func lookup(barcode: String) async -> BarcodeMatch? {
        let codes = normalisedCodes(from: barcode)
        guard !codes.isEmpty else { return nil }

        // Gather every candidate from every source concurrently, then score.
        let candidates = await withTaskGroup(of: Candidate?.self) { group -> [Candidate] in
            for code in codes {
                group.addTask { await queryOpenFacts(host: "https://world.openbeautyfacts.org", code: code, source: .beauty) }
                group.addTask { await queryOpenFacts(host: "https://world.openfoodfacts.org", code: code, source: .food) }
                group.addTask { await queryOpenFacts(host: "https://world.openproductsfacts.org", code: code, source: .products) }
                group.addTask { await queryUPCItemDB(code: code) }
            }
            var found: [Candidate] = []
            for await result in group { if let result { found.append(result) } }
            return found
        }

        guard let best = candidates.max(by: { $0.score < $1.score }) else { return nil }
        return BarcodeMatch(name: best.name, brand: best.brand, domain: best.domain, imageURL: best.imageURL)
    }

    /// Download a product image from a database URL, downscaled for storage.
    static func imageData(from urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let image = UIImage(data: data) else { return nil }
        return downscaledJPEG(image)
    }

    // MARK: - Candidate

    private enum Source { case beauty, food, products, upc }

    private struct Candidate {
        let name: String
        let brand: String
        let domain: Domain
        let imageURL: String?
        let source: Source

        /// Higher is better. Rewards complete data and self-care relevance.
        var score: Int {
            var s = 0
            if !name.isEmpty { s += 4 }
            if !brand.isEmpty { s += 2 }
            if imageURL != nil { s += 2 }
            switch source {
            case .beauty: s += 3   // most relevant to a self-care app
            case .upc: s += 2      // strong general retail accuracy
            case .products: s += 1
            case .food: s += 1
            }
            return s
        }
    }

    // MARK: - Barcode normalisation

    /// Return the distinct codes worth querying: the digits as scanned, the
    /// UPC-A expansion of any UPC-E code, and the EAN-13 (leading-zero) form.
    private static func normalisedCodes(from raw: String) -> [String] {
        let digits = raw.filter(\.isNumber)
        guard !digits.isEmpty else { return [] }

        var codes: [String] = [digits]
        if digits.count == 8, let expanded = expandUPCE(digits) { codes.append(expanded) }
        if digits.count == 12 { codes.append("0" + digits) } // UPC-A → EAN-13
        // De-dup while keeping order.
        var seen = Set<String>()
        return codes.filter { seen.insert($0).inserted }
    }

    /// Expand a zero-suppressed 8-digit UPC-E code to its 12-digit UPC-A form.
    private static func expandUPCE(_ upce: String) -> String? {
        let d = Array(upce)
        guard d.count == 8, d.first == "0" else { return nil }
        let m = Array(d[1...6]) // manufacturer/product digits
        let check = d[7]
        let last = m[5]
        var mid: String
        switch last {
        case "0", "1", "2":
            mid = "\(m[0])\(m[1])\(last)0000\(m[2])\(m[3])\(m[4])"
        case "3":
            mid = "\(m[0])\(m[1])\(m[2])00000\(m[3])\(m[4])"
        case "4":
            mid = "\(m[0])\(m[1])\(m[2])\(m[3])00000\(m[4])"
        default:
            mid = "\(m[0])\(m[1])\(m[2])\(m[3])\(m[4])0000\(last)"
        }
        return "0" + mid + String(check)
    }

    // MARK: - Open*Facts query

    private static func queryOpenFacts(host: String, code: String, source: Source) async -> Candidate? {
        let fields = "product_name,product_name_en,brands,image_front_url,image_url,categories_tags"
        guard let url = URL(string: "\(host)/api/v2/product/\(code).json?fields=\(fields)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("LUMEN/1.0 (self-care ritual app)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(OpenFactsResponse.self, from: data),
              decoded.status == 1, let product = decoded.product else { return nil }

        let name = (product.product_name_en?.nonEmpty ?? product.product_name?.nonEmpty) ?? ""
        guard !name.isEmpty else { return nil }

        let brand = product.brands?.components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let domain = mapDomain(host: host, categories: product.categories_tags ?? [])
        let imageURL = product.image_front_url?.nonEmpty ?? product.image_url?.nonEmpty
        return Candidate(name: name, brand: brand, domain: domain, imageURL: imageURL, source: source)
    }

    // MARK: - UPCitemdb query (free trial endpoint, no key)

    private static func queryUPCItemDB(code: String) async -> Candidate? {
        guard let url = URL(string: "https://api.upcitemdb.com/prod/trial/lookup?upc=\(code)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 12

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              let decoded = try? JSONDecoder().decode(UPCItemDBResponse.self, from: data),
              let item = decoded.items?.first,
              let name = item.title?.nonEmpty else { return nil }

        let brand = item.brand?.nonEmpty ?? ""
        let category = item.category ?? ""
        let domain = mapDomain(host: "", categories: [category.lowercased()])
        let imageURL = item.images?.first(where: { $0.nonEmpty != nil })
        return Candidate(name: name, brand: brand, domain: domain, imageURL: imageURL, source: .upc)
    }

    // MARK: - Category mapping

    private static func mapDomain(host: String, categories: [String]) -> Domain {
        let tags = categories.map { $0.lowercased() }
        func has(_ keywords: [String]) -> Bool {
            tags.contains { tag in keywords.contains { tag.contains($0) } }
        }

        if has(["shampoo", "hair", "conditioner", "scalp"]) { return .hair }
        if has(["shaving", "shave", "razor", "beard", "deodorant", "antiperspirant", "fragrance", "cologne", "aftershave", "perfume"]) { return .grooming }
        if has(["supplement", "vitamin", "protein", "tea", "drink", "water", "food", "snack", "beverage"]) { return .health }
        if has(["sleep", "melatonin", "pillow", "lavender", "night-balm"]) { return .sleep }
        if has(["skin", "face", "serum", "moisturiz", "moisturis", "cream", "cleanser", "sunscreen", "lotion", "cosmetic", "beauty", "lip", "eye"]) { return .skin }

        // Open Beauty Facts → skin by default; Open Food Facts → health.
        if host.contains("openfoodfacts") { return .health }
        if host.contains("openbeautyfacts") { return .skin }
        return .skin
    }

    // MARK: - Image helpers

    private static func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat = 1024) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

// MARK: - Open*Facts response

private nonisolated struct OpenFactsResponse: Decodable {
    let status: Int?
    let product: OpenFactsProduct?
}

private nonisolated struct OpenFactsProduct: Decodable {
    let product_name: String?
    let product_name_en: String?
    let brands: String?
    let image_url: String?
    let image_front_url: String?
    let categories_tags: [String]?
}

// MARK: - UPCitemdb response

private nonisolated struct UPCItemDBResponse: Decodable {
    let items: [UPCItem]?
}

private nonisolated struct UPCItem: Decodable {
    let title: String?
    let brand: String?
    let category: String?
    let images: [String]?
}

private extension String {
    nonisolated var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
