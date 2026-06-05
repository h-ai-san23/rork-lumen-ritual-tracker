//
//  RitualLiveActivity.swift
//  LUMEN
//
//  Starts, updates, and ends the ritual Live Activity so an in-progress ritual
//  appears on the Lock Screen and in the Dynamic Island — with a step timer
//  that keeps counting down while the app is in the background.
//

import Foundation
import ActivityKit

@MainActor
final class RitualLiveActivity {
    static let shared = RitualLiveActivity()
    private init() {}

    private var activity: Activity<RitualActivityAttributes>?

    /// Whether the user has Live Activities enabled for LUMEN.
    var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Begin a Live Activity for a freshly started ritual.
    func start(ritualName: String, ritualSymbol: String, state: RitualActivityAttributes.ContentState) {
        guard isAvailable else { return }
        endImmediately()

        let attributes = RitualActivityAttributes(ritualName: ritualName, ritualSymbol: ritualSymbol)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            activity = nil
        }
    }

    /// Push a new step / timer state to the running activity.
    func update(_ state: RitualActivityAttributes.ContentState) {
        guard let activity else { return }
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    /// End the activity (ritual finished or player dismissed).
    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// Tear down any stale activities synchronously before starting a new one.
    private func endImmediately() {
        for existing in Activity<RitualActivityAttributes>.activities {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
        }
        activity = nil
    }
}
