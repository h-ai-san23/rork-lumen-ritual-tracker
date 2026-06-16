//
//  ProductAIService.swift
//  LUMEN
//
//  Identifies a product from a photo or a scanned barcode and drafts its
//  details (name, brand, category, shelf-life). Routes through the Rork AI
//  proxy. The user's photo is kept as the product image; for barcode-only
//  scans a clean product image is generated.
//

import Foundation
import UIKit

/// AI-drafted product details, ready to drop into the add-product form.
nonisolated struct ProductDraft: Sendable {
    var name: String
    var brand: String
    var domain: Domain
    var paoMonths: Int
    var notes: String
    /// Optional AI-generated product image (used for barcode-only scans).
    var imageData: Data?
}

nonisolated enum ProductAIError: LocalizedError {
    case notConfigured
    case imageProcessingFailed
    case authError
    case insufficientBalance
    case rateLimited
    case serverError(Int)
    case couldNotIdentify

    var errorDescription: String? {
        switch self {
        case .notConfigured:       "AI isn't set up yet. Enable Rork AI Cloud to scan products."
        case .imageProcessingFailed: "Couldn't read that photo. Please try another."
        case .authError:           "AI features are currently unavailable. Please try again later."
        case .insufficientBalance: "AI features are temporarily unavailable. Please try again later."
        case .rateLimited:         "Too many requests. Please wait a moment and try again."
        case .serverError:         "Something went wrong. Please try again."
        case .couldNotIdentify:    "Couldn't recognise this product. Try a clearer photo or add it manually."
        }
    }
}

enum ProductAIService {
    // MARK: - Config

    private static var baseURL: String { Config.EXPO_PUBLIC_TOOLKIT_URL }
    private static var secret: String { Config.EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY }

    static var isConfigured: Bool {
        !secret.isEmpty && !baseURL.isEmpty
    }

    /// Vision + reasoning model used to read the product and return structured JSON.
    private static let identifyModel = "google/gemini-2.5-flash"
    /// Image model used to render a clean product shot for barcode-only scans.
    private static let imageModel = "google/gemini-3.1-flash-image-preview"

    private static let systemPrompt = """
    You are a self-care product cataloguer for the Lumira app. Identify the product and \
    respond with STRICT JSON only, no markdown, matching exactly:
    {"name": string, "brand": string, "category": one of ["skin","hair","grooming","sleep","health"], \
    "paoMonths": integer (typical period-after-opening in months, 1-36), "notes": short one-sentence description}
    If you cannot identify it, set name to "" . Keep names concise (e.g. "Vitamin C Serum").
    """

    // MARK: - Public API

    /// Identify a product from a user photo. The photo is returned as the image.
    static func identify(from imageData: Data) async throws -> ProductDraft {
        guard isConfigured else { throw ProductAIError.notConfigured }
        guard let base64 = downscaledJPEGBase64(imageData) else { throw ProductAIError.imageProcessingFailed }

        let content: [[String: Any]] = [
            ["type": "text", "text": "Identify this self-care product."],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]],
        ]
        var draft = try await requestDraft(userContent: content)
        draft.imageData = imageData
        return draft
    }

    /// Identify a product from a scanned barcode.
    ///
    /// Looks the code up in the open product databases first (exact match with
    /// the real product name, brand, and photo). Only if no database recognises
    /// the code does it fall back to AI identification.
    static func identify(barcode: String) async throws -> ProductDraft {
        if let match = await BarcodeLookupService.lookup(barcode: barcode) {
            var draft = ProductDraft(
                name: match.name,
                brand: match.brand,
                domain: match.domain,
                paoMonths: 12,
                notes: "",
                imageData: nil
            )
            if let imageURL = match.imageURL {
                draft.imageData = await BarcodeLookupService.imageData(from: imageURL)
            }
            // Enrich shelf-life / description with AI when available; never fatal.
            if isConfigured, let enriched = try? await enrich(draft) {
                draft.paoMonths = enriched.paoMonths
                draft.notes = enriched.notes
            }
            if draft.imageData == nil, isConfigured {
                draft.imageData = try? await generateImage(for: draft)
            }
            return draft
        }

        // No database match — fall back to AI identification from the code.
        guard isConfigured else { throw ProductAIError.couldNotIdentify }
        let content: [[String: Any]] = [
            ["type": "text", "text": "Identify the self-care product with this barcode/UPC: \(barcode)."],
        ]
        var draft = try await requestDraft(userContent: content)
        draft.imageData = try? await generateImage(for: draft)
        return draft
    }

    /// Ask the model only for shelf-life + a short description of a known product.
    private static func enrich(_ draft: ProductDraft) async throws -> ProductDraft {
        let content: [[String: Any]] = [[
            "type": "text",
            "text": "For the product \"\(draft.brand) \(draft.name)\" return the catalogue JSON.",
        ]]
        return try await requestDraft(userContent: content)
    }

    // MARK: - Identification request

    private static func requestDraft(userContent: [[String: Any]]) async throws -> ProductDraft {
        let body: [String: Any] = [
            "model": identifyModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContent],
            ],
        ]
        let data = try await postChat(body: body)

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content else { throw ProductAIError.couldNotIdentify }
        return try parseDraft(from: text)
    }

    private static func parseDraft(from text: String) throws -> ProductDraft {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            throw ProductAIError.couldNotIdentify
        }
        let json = String(text[start...end])
        struct Raw: Decodable {
            let name: String
            let brand: String?
            let category: String?
            let paoMonths: Int?
            let notes: String?
        }
        guard let raw = try? JSONDecoder().decode(Raw.self, from: Data(json.utf8)),
              !raw.name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ProductAIError.couldNotIdentify
        }
        let domain = Domain(rawValue: raw.category ?? "skin") ?? .skin
        let pao = min(36, max(1, raw.paoMonths ?? 12))
        return ProductDraft(name: raw.name, brand: raw.brand ?? "", domain: domain,
                            paoMonths: pao, notes: raw.notes ?? "", imageData: nil)
    }

    // MARK: - Image generation

    private static func generateImage(for draft: ProductDraft) async throws -> Data? {
        let prompt = """
        A clean, minimal product photograph of "\(draft.brand) \(draft.name)" \
        (\(draft.domain.title) product), centred on a soft warm neutral background, \
        studio lighting, premium quiet-luxury aesthetic.
        """
        let body: [String: Any] = [
            "model": imageModel,
            "modalities": ["text", "image"],
            "messages": [["role": "user", "content": [["type": "text", "text": prompt]]]],
        ]
        let data = try await postChat(body: body)

        struct ImageResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let images: [String]? }
                let message: Message
            }
            let choices: [Choice]
        }
        guard let decoded = try? JSONDecoder().decode(ImageResponse.self, from: data),
              let dataURI = decoded.choices.first?.message.images?.first else { return nil }
        let parts = dataURI.components(separatedBy: ",")
        let base64 = parts.count == 2 ? parts[1] : dataURI
        return Data(base64Encoded: base64)
    }

    // MARK: - Networking

    private static func postChat(body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/v2/vercel/v1/chat/completions") else {
            throw ProductAIError.serverError(0)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(secret)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 90

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProductAIError.serverError(0) }
        switch http.statusCode {
        case 200: return data
        case 401: throw ProductAIError.authError
        case 402: throw ProductAIError.insufficientBalance
        case 429: throw ProductAIError.rateLimited
        default:  throw ProductAIError.serverError(http.statusCode)
        }
    }

    // MARK: - Image helpers

    /// Downscale a photo against a byte budget so it fits the proxy body limit.
    private static func downscaledJPEGBase64(_ data: Data, maxBytes: Int = 3_000_000) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        for maxDimension in [1280.0, 1024.0, 832.0, 640.0, 512.0] {
            let scaled = resized(image, maxDimension: maxDimension)
            for quality in [0.8, 0.7, 0.6] {
                if let jpeg = scaled.jpegData(compressionQuality: quality), jpeg.count <= maxBytes {
                    return jpeg.base64EncodedString()
                }
            }
        }
        return image.jpegData(compressionQuality: 0.5)?.base64EncodedString()
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }
}
