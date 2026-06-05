//
//  Product.swift
//  LUMEN
//
//  A product on the user's shelf.
//

import Foundation
import SwiftData

@Model
final class Product {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var domainRaw: String = Domain.skin.rawValue
    @Attribute(.externalStorage) var imageData: Data?
    var openedDate: Date?
    var paoMonths: Int = 12
    var usageCount: Int = 0
    var cost: Double = 0
    var lowFlag: Bool = false
    var notes: String = ""
    var reorderUrl: String = ""
    var createdAt: Date = Date()

    init(
        name: String,
        brand: String = "",
        domain: Domain = .skin,
        openedDate: Date? = Date(),
        paoMonths: Int = 12,
        cost: Double = 0,
        notes: String = "",
        reorderUrl: String = ""
    ) {
        self.name = name
        self.brand = brand
        self.domainRaw = domain.rawValue
        self.openedDate = openedDate
        self.paoMonths = paoMonths
        self.cost = cost
        self.notes = notes
        self.reorderUrl = reorderUrl
    }

    var domain: Domain {
        get { Domain(rawValue: domainRaw) ?? .skin }
        set { domainRaw = newValue.rawValue }
    }

    /// Cost divided by number of uses so far.
    var costPerUse: Double {
        usageCount > 0 ? cost / Double(usageCount) : cost
    }

    /// The date the product expires based on Period-After-Opening.
    var expiryDate: Date? {
        guard let openedDate else { return nil }
        return Calendar.current.date(byAdding: .month, value: paoMonths, to: openedDate)
    }

    /// True if expiring within 30 days or already expired.
    var isExpiringSoon: Bool {
        guard let expiryDate else { return false }
        return expiryDate.timeIntervalSinceNow < 30 * 24 * 3600
    }

    /// Needs the user's attention — running low or expiring soon.
    var needsAttention: Bool { lowFlag || isExpiringSoon }
}
