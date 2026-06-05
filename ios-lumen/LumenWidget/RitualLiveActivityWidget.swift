//
//  RitualLiveActivityWidget.swift
//  LumenWidget
//
//  The ritual Live Activity: a quiet-luxury Lock Screen banner and Dynamic
//  Island presentation that shows the current step and a live step timer.
//

import WidgetKit
import SwiftUI
import ActivityKit

struct RitualLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RitualActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(LumenWidgetColors.bg.opacity(0.92))
                .activitySystemActionForegroundColor(LumenWidgetColors.gold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.domainSymbol)
                        .font(.title3)
                        .foregroundStyle(LumenWidgetColors.goldGradient)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    trailing(context).foregroundStyle(LumenWidgetColors.gold)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.ritualName.uppercased())
                            .font(.caption2).tracking(1.2)
                            .foregroundStyle(LumenWidgetColors.secondary)
                        Text(context.state.stepTitle)
                            .font(.headline)
                            .foregroundStyle(LumenWidgetColors.text)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    progressBar(context)
                }
            } compactLeading: {
                Image(systemName: context.attributes.ritualSymbol)
                    .foregroundStyle(LumenWidgetColors.gold)
            } compactTrailing: {
                trailing(context)
                    .foregroundStyle(LumenWidgetColors.gold)
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: context.attributes.ritualSymbol)
                    .foregroundStyle(LumenWidgetColors.gold)
            }
            .keylineTint(LumenWidgetColors.gold)
        }
    }

    // MARK: - Lock Screen

    private func lockScreen(_ context: ActivityViewContext<RitualActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(LumenWidgetColors.gold.opacity(0.14)).frame(width: 46, height: 46)
                Image(systemName: context.state.domainSymbol)
                    .font(.title3)
                    .foregroundStyle(LumenWidgetColors.goldGradient)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.ritualName.uppercased())
                    .font(.caption2).tracking(1.4)
                    .foregroundStyle(LumenWidgetColors.secondary)
                Text(context.state.stepTitle)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(LumenWidgetColors.text)
                    .lineLimit(1)
                Text("Step \(context.state.stepNumber) of \(context.state.totalSteps)")
                    .font(.caption2)
                    .foregroundStyle(LumenWidgetColors.secondary)
            }
            Spacer(minLength: 8)
            trailing(context)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(LumenWidgetColors.goldGradient)
        }
        .padding(16)
    }

    // MARK: - Pieces

    @ViewBuilder
    private func trailing(_ context: ActivityViewContext<RitualActivityAttributes>) -> some View {
        if let end = context.state.timerEndDate, end > .now {
            Text(timerInterval: Date.now...end, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text("\(context.state.stepNumber)/\(context.state.totalSteps)")
                .monospacedDigit()
        }
    }

    private func progressBar(_ context: ActivityViewContext<RitualActivityAttributes>) -> some View {
        let fraction = context.state.totalSteps > 0
            ? Double(context.state.stepNumber) / Double(context.state.totalSteps)
            : 0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(LumenWidgetColors.gold.opacity(0.18))
                Capsule().fill(LumenWidgetColors.goldGradient)
                    .frame(width: max(6, geo.size.width * fraction))
            }
        }
        .frame(height: 5)
        .padding(.top, 4)
    }
}
