//
//  RitualStep.swift
//  LUMEN
//
//  A single step within the AM or PM ritual.
//

import Foundation
import SwiftData

@Model
final class RitualStep {
    var id: UUID = UUID()
    var ritualRaw: String = RitualTime.am.rawValue
    var domainRaw: String = Domain.skin.rawValue
    var title: String = ""
    var howTo: String = ""
    var timerSeconds: Int = 0
    var productID: UUID?
    var order: Int = 0

    init(
        ritual: RitualTime,
        domain: Domain,
        title: String,
        howTo: String,
        timerSeconds: Int = 0,
        productID: UUID? = nil,
        order: Int
    ) {
        self.ritualRaw = ritual.rawValue
        self.domainRaw = domain.rawValue
        self.title = title
        self.howTo = howTo
        self.timerSeconds = timerSeconds
        self.productID = productID
        self.order = order
    }

    var ritual: RitualTime {
        get { RitualTime(rawValue: ritualRaw) ?? .am }
        set { ritualRaw = newValue.rawValue }
    }

    var domain: Domain {
        get { Domain(rawValue: domainRaw) ?? .skin }
        set { domainRaw = newValue.rawValue }
    }
}
