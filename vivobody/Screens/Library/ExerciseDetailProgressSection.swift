//
//  ExerciseDetailProgressSection.swift
//  vivobody
//
//  Binding-driven Exercise Detail progress leaf. It renders immutable chart
//  presentation without owning archive queries, analytics, or paywall state.
//

import Charts
import SwiftUI
import VivoKit

struct ExerciseDetailProgressSection: View {
    let readModel: ExerciseDetailReadModel
    let unit: WeightUnit
    @Binding var selectedMetric: ExerciseDetailChartMetric
    @Binding var selectedRange: ExerciseDetailChartRange
    let isUnlocked: Bool
    let onUnlock: () -> Void

    var body: some View {
        if readModel.hasHistory || readModel.exercise.supportsEstimatedOneRepMax {
            if isUnlocked {
                progressSection
            } else {
                lockedProgressSection
            }
        }
    }

    private var presentation: ExerciseDetailChartPresentation {
        ExerciseDetailChartPresentation(
            readModel: readModel,
            selectedMetric: selectedMetric,
            range: selectedRange,
            unit: unit
        )
    }

    private var progressSection: some View {
        let presentation = presentation
        return VStack(alignment: .leading, spacing: Space.lg) {
            Text(presentation.isStrengthTrend ? "Strength trend" : "Progress")
                .sectionLabelStyle(Opacity.medium)

            if readModel.exercise.trackingMode == .reps {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(presentation.availableMetrics) { metric in
                            metricChip(metric, presentation: presentation)
                        }
                    }
                }
            }

            if presentation.isStrengthTrend {
                ExerciseStrengthTrendCard(
                    exerciseName: readModel.exercise.name,
                    progress: presentation.progressThroughNow,
                    stat: readModel.strengthTrendStat,
                    readinessDates: presentation.strengthTrendReadinessDates,
                    visiblePoints: presentation.visiblePoints,
                    rangeLabel: presentation.range.trendLabel,
                    unit: unit
                )
            } else {
                genericChart(presentation)
            }

            if presentation.showsRangeControls {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(ExerciseDetailChartRange.allCases) { range in
                            rangeChip(range)
                        }
                    }
                }
            }
        }
    }

    private func metricChip(
        _ metric: ExerciseDetailChartMetric,
        presentation: ExerciseDetailChartPresentation
    ) -> some View {
        let isSelected = metric == presentation.effectiveMetric
        return Button {
            Haptics.selection()
            selectedMetric = metric
        } label: {
            Text(metric.label)
                .font(Typography.metricUnit)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(minHeight: Space.tapMin)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .coloredGlassControl(
                    cornerRadius: Radius.pill,
                    fill: isSelected ? Tint.inProgress : nil
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    @ViewBuilder
    private func genericChart(
        _ presentation: ExerciseDetailChartPresentation
    ) -> some View {
        if let placeholder = presentation.placeholder {
            DormantChartCard(
                legend: placeholder.legend,
                unitLabel: placeholder.unitLabel,
                plottedValue: placeholder.plottedValue,
                showsNextSlot: placeholder.showsNextSlot
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(placeholder.accessibilityLabel)
        } else {
            Chart {
                ForEach(presentation.plottablePoints) { plotted in
                    LineMark(
                        x: .value("Date", plotted.point.date),
                        y: .value(
                            presentation.metricAccessibilityName,
                            plotted.value
                        )
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Ink.primary.opacity(Opacity.strong))

                    AreaMark(
                        x: .value("Date", plotted.point.date),
                        y: .value(
                            presentation.metricAccessibilityName,
                            plotted.value
                        )
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Tint.primary.opacity(0.22),
                                Tint.primary.opacity(0),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    if presentation.personalRecordPointIDs.contains(plotted.id) {
                        PointMark(
                            x: .value("Date", plotted.point.date),
                            y: .value(
                                presentation.metricAccessibilityName,
                                plotted.value
                            )
                        )
                        .symbol(.circle)
                        .symbolSize(60)
                        .foregroundStyle(Tint.complete)
                    }
                }

                if let last = presentation.plottablePoints.last {
                    PointMark(
                        x: .value("Date", last.point.date),
                        y: .value(
                            presentation.metricAccessibilityName,
                            last.value
                        )
                    )
                    .symbol(.circle)
                    .symbolSize(60)
                    .foregroundStyle(Tint.complete)
                    .annotation(
                        position: .top,
                        alignment: .trailing,
                        spacing: 6
                    ) {
                        Text(last.valueLabel)
                            .font(Typography.metricUnit)
                            .foregroundStyle(Ink.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Surface.edge)
                    AxisValueLabel()
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Surface.edge)
                    AxisValueLabel()
                        .font(Typography.metricMicro)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            .frame(height: 200)
            .padding(Space.md)
            .contentCard()
            .accessibilityLabel(presentation.chartAccessibilityLabel)
            .accessibilityValue(presentation.chartAccessibilityValue)
        }
    }

    private func rangeChip(_ range: ExerciseDetailChartRange) -> some View {
        let isSelected = range == selectedRange
        return Button {
            Haptics.selection()
            selectedRange = range
        } label: {
            Text(range.label)
                .font(Typography.metricUnit)
                .foregroundStyle(isSelected ? Tint.onAccent : Ink.secondary)
                .frame(minWidth: Space.tapMin, minHeight: Space.tapMin)
                .padding(.horizontal, 12)
                .coloredGlassControl(
                    cornerRadius: Radius.pill,
                    fill: isSelected ? Tint.inProgress : nil
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var lockedProgressSection: some View {
        Button {
            Haptics.soft()
            onUnlock()
        } label: {
            progressSection
                .blur(radius: 12)
                .allowsHitTesting(false)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Progress chart, locked")
        .accessibilityHint("Unlocks with Vivobody Pro")
    }
}
