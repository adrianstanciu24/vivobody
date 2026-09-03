//
//  ReadinessCardGallery.swift
//  vivobody
//
//  DEBUG gallery for Today's Training Load instrument: both volume-load
//  and hard-set measures across stable and forming personal ranges.
//  Dedicated previews exercise both appearances and Accessibility type.
//

#if DEBUG
    import SwiftUI
    import VivoKit

    struct ReadinessCardGallery: View {
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xxl) {
                    header

                    labelled("Volume load · within range · partial") {
                        ReadinessCard(
                            report: Self.report(
                                loads: [3200, 0, 4100, 0, 0, 5200, 3900],
                                comparisonRatio: 1,
                                verdict: .productive,
                                measure: .volumeLoad,
                                loadAvailability: .partial
                            ),
                            line: ReadinessLine(
                                lead: "Productive training load.",
                                tail: "Keep the rhythm."
                            )
                        )
                    }

                    labelled("Volume load · unavailable this week") {
                        ReadinessCard(
                            report: Self.report(
                                loads: [0, 0, 0, 0, 0, 0, 0],
                                comparisonRatio: 0,
                                verdict: .low,
                                measure: .volumeLoad,
                                loadAvailability: .unavailable,
                                usualLoad: 18400
                            ),
                            line: ReadinessLine(
                                lead: "Load is lighter lately.",
                                tail: "Build when ready."
                            )
                        )
                    }

                    labelled("Hard sets · above range") {
                        ReadinessCard(
                            report: Self.report(
                                loads: [5, 6, 0, 7, 6, 8, 0],
                                comparisonRatio: 1.6,
                                verdict: .high
                            ),
                            line: ReadinessLine(
                                lead: "Training load is high.",
                                tail: "Keep today lighter."
                            )
                        )
                    }

                    labelled("Below range") {
                        ReadinessCard(
                            report: Self.report(
                                loads: [0, 2, 0, 0, 0, 3, 0],
                                comparisonRatio: 0.5,
                                verdict: .low
                            ),
                            line: ReadinessLine(
                                lead: "Load is lighter lately.",
                                tail: "Build when ready."
                            )
                        )
                    }

                    labelled("Personal range forming") {
                        ReadinessCard(
                            report: Self.report(
                                loads: [0, 0, 4, 0, 3, 0, 0],
                                comparisonRatio: 1.1,
                                verdict: .insufficient
                            ),
                            line: ReadinessLine(
                                lead: "Fresh — 2 days' rest.",
                                tail: "Good to go."
                            )
                        )
                    }
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.section)
                .padding(.bottom, Space.xxl)
            }
            .screenBackground()
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Training load instrument")
                    .panelLegend()
                Text("Current versus your range")
                    .font(Typography.display)
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("The qualitative read and one labelled scale lead. Daily history stays secondary.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        private func labelled(
            _ title: String,
            @ViewBuilder content: () -> some View
        ) -> some View {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text(title)
                    .panelLegend()
                content()
            }
        }

        /// Fabricated report: daily loads are oldest first and end today.
        /// Stable fixtures derive their usual load from the supplied ratio,
        /// keeping the displayed numbers, band, marker, and verdict coherent.
        fileprivate static func report(
            loads: [Double],
            comparisonRatio: Double,
            verdict: LoadVerdict,
            measure: TrainingLoadMeasure = .hardSets,
            loadAvailability: ComparableTonnageAvailability = .complete,
            usualLoad explicitUsualLoad: Double? = nil
        ) -> TrainingLoadReport {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let today = calendar.date(
                from: DateComponents(year: 2026, month: 8, day: 22)
            )!
            let days = loads.enumerated().compactMap { index, load -> DayLoad? in
                guard let date = calendar.date(
                    byAdding: .day,
                    value: index - (loads.count - 1),
                    to: today
                ) else { return nil }
                return DayLoad(date: date, load: load)
            }
            let current = loads.reduce(0, +)
            let isForming = verdict == .insufficient
            let derivedUsual = isForming || comparisonRatio <= 0
                ? nil
                : current / comparisonRatio
            let usual = explicitUsualLoad ?? derivedUsual

            return TrainingLoadReport(
                currentLoad: current,
                usualLoad: usual,
                ratio: isForming ? 0 : comparisonRatio,
                provisionalRatio: isForming ? comparisonRatio : nil,
                verdict: verdict,
                daysLogged: isForming ? 18 : 60,
                activeBaselineWeeks: isForming ? 2 : 4,
                points: [],
                recentDays: days,
                drivers: .empty,
                measure: measure,
                loadAvailability: loadAvailability
            )
        }
    }

    #Preview("Readiness Card · Dark") {
        ReadinessCardGallery()
            .preferredColorScheme(.dark)
    }

    #Preview("Readiness Card · Light") {
        ReadinessCardGallery()
            .preferredColorScheme(.light)
    }

    #Preview("Readiness Card · Accessibility") {
        ReadinessCard(
            report: ReadinessCardGallery.report(
                loads: [3200, 0, 4100, 0, 0, 5200, 3900],
                comparisonRatio: 1,
                verdict: .productive,
                measure: .volumeLoad,
                loadAvailability: .partial
            ),
            line: ReadinessLine(
                lead: "Productive training load.",
                tail: "Keep the rhythm."
            )
        )
        .padding(Space.gutter)
        .screenBackground()
        .dynamicTypeSize(.accessibility3)
        .preferredColorScheme(.dark)
    }
#endif
