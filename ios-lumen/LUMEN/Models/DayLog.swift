//
//  DayLog.swift
//  LUMEN
//
//  A daily record of completion and self-tracked metrics.
//

import Foundation
import SwiftData

@Model
final class DayLog {
    /// Normalised to the start of the day.
    var date: Date = Calendar.current.startOfDay(for: Date())
    var completedStepIDs: [String] = []
    var skinRating: Int?
    var sleepHours: Double?
    var mood: Int?
    @Attribute(.externalStorage) var photoData: Data?

    init(date: Date = Calendar.current.startOfDay(for: Date())) {
        self.date = Calendar.current.startOfDay(for: date)
    }

    func isComplete(_ step: RitualStep) -> Bool {
        completedStepIDs.contains(step.id.uuidString)
    }
}
