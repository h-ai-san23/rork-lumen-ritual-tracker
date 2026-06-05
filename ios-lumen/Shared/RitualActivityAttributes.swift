//
//  RitualActivityAttributes.swift
//  LUMEN — shared between the app and the LumenWidget extension.
//
//  Describes the data shown in the ritual Live Activity (Lock Screen banner +
//  Dynamic Island). The countdown is driven by `timerEndDate` so the system
//  renders a live ticking timer even while the app is backgrounded.
//

import Foundation
import ActivityKit

nonisolated struct RitualActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        /// Current step title, e.g. "Cleanse".
        var stepTitle: String
        /// 1-based position of the current step.
        var stepNumber: Int
        /// Total steps in this ritual.
        var totalSteps: Int
        /// SF Symbol for the step's domain.
        var domainSymbol: String
        /// When the active step timer finishes. Nil when no timer is running.
        var timerEndDate: Date?
    }

    /// "Morning Ritual" / "Evening Ritual" — set once when the activity starts.
    var ritualName: String
    /// SF Symbol for the ritual (sun / moon).
    var ritualSymbol: String
}
