//
//  InsightChartKitGallery.swift
//  vivobody
//
//  Debug-only gallery for the shared Insights chart vocabulary. Populated
//  states draw invented demo series with the common axis chrome and
//  micro-legend at both canvas heights; dormant states are the exact
//  placeholders sections render before their data qualifies. Keeps empty,
//  partial, populated, large-type, and light-appearance states visible
//  while tuning the chart family.
//

#if DEBUG
    import Charts
    import SwiftUI
    import VivoKit

    // MARK: - Demo series (invented; never shown to users)

    private struct GalleryTrendPoint: Identifiable {
        let dayOffset: Int
        let value: Double

        var id: Int {
            dayOffset
        }

        var date: Date {
            Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
        }
    }

    private struct GalleryWeekPoint: Identifiable {
        let week: Int
        let sets: Int

        var id: Int {
            week
        }
    }

    private struct GalleryZoneStack: Identifiable {
        let week: Int
        let zone: String
        let sets: Int

        var id: String {
            "\(week)-\(zone)"
        }
    }

    private enum GalleryDemo {
        static let trendValues: [Double] = [
            6, 9, 7, 11, 10, 13, 12, 15, 13, 16, 14, 17, 15, 18, 16, 19, 17, 20, 18, 21, 19,
        ]

        static let trend: [GalleryTrendPoint] = trendValues.enumerated().map { index, value in
            GalleryTrendPoint(dayOffset: index - trendValues.count + 1, value: value)
        }

        static let weeklySets: [GalleryWeekPoint] = [
            12, 15, 9, 18, 20, 14, 22, 17, 25, 21, 27, 24,
        ].enumerated().map { index, sets in
            GalleryWeekPoint(week: index, sets: sets)
        }

        /// Twelve weeks of low/moderate/high rep work; moderate wears the
        /// accent as the dominant zone.
        static let zoneStacks: [GalleryZoneStack] = (0 ..< 12).flatMap { week in
            [
                GalleryZoneStack(week: week, zone: "Low", sets: 3 + week % 3),
                GalleryZoneStack(week: week, zone: "Moderate", sets: 8 + (week * 2) % 5),
                GalleryZoneStack(week: week, zone: "High", sets: 2 + week % 4),
            ]
        }

        static func zoneColor(_ zone: String) -> Color {
            switch zone {
            case "Moderate": Tint.primary
            case "Low": Ink.primary.opacity(0.46)
            default: Ink.primary.opacity(0.20)
            }
        }
    }

    // MARK: - Populated states

    #Preview("Insight chart · hero line") {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Space.sm) {
                InsightChartLegend(
                    items: [
                        InsightChartLegend.Item(label: "7-day load", color: Tint.primary),
                        InsightChartLegend.Item(label: "Recent range", color: Tint.primary.opacity(0.22)),
                    ],
                    trailing: "LAST 28 DAYS"
                )

                Chart(GalleryDemo.trend) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Load", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Tint.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                .chartXAxis { InsightChartAxis.dates() }
                .chartYAxis { InsightChartAxis.counts() }
                .frame(height: InsightChartCanvas.hero)
            }
            .padding(Space.xl)
            .contentCard()
            .padding(Space.gutter)
        }
        .preferredColorScheme(.dark)
    }

    #Preview("Insight chart · stacked bars") {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Space.sm) {
                InsightChartLegend(
                    items: [
                        InsightChartLegend.Item(label: "Moderate", color: Tint.primary, swatch: .fill),
                        InsightChartLegend.Item(label: "Low", color: Ink.primary.opacity(0.46), swatch: .fill),
                        InsightChartLegend.Item(label: "High", color: Ink.primary.opacity(0.20), swatch: .fill),
                    ],
                    trailing: "LAST 12 WEEKS"
                )

                Chart(GalleryDemo.zoneStacks) { stack in
                    BarMark(
                        x: .value("Week", stack.week),
                        y: .value("Sets", stack.sets)
                    )
                    .foregroundStyle(GalleryDemo.zoneColor(stack.zone))
                    .cornerRadius(2)
                }
                .chartXAxis {
                    InsightChartAxis.values(desiredCount: 4) { "W\(Int($0.rounded()))" }
                }
                .chartYAxis { InsightChartAxis.counts() }
                .frame(height: InsightChartCanvas.hero)
            }
            .padding(Space.xl)
            .contentCard()
            .padding(Space.gutter)
        }
        .preferredColorScheme(.dark)
    }

    #Preview("Insight chart · compact sparkline") {
        ZStack {
            Color.black.ignoresSafeArea()
            Chart(GalleryDemo.weeklySets) { point in
                AreaMark(
                    x: .value("Week", point.week),
                    y: .value("Sets", point.sets)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Tint.primary.opacity(0.28), Tint.primary.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Week", point.week),
                    y: .value("Sets", point.sets)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Tint.primary.opacity(Opacity.strong))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: InsightChartCanvas.compact)
            .padding(Space.xl)
            .contentCard()
            .padding(Space.gutter)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Dormant states

    #Preview("Dormant canvas · empty") {
        ZStack {
            Color.black.ignoresSafeArea()
            DormantSlotsCanvas(
                slotCount: 6,
                filledSlots: 0,
                legend: "0/6 STRENGTH SETS",
                accessibilityLabel: "Signal building. 0 of 6 strength sets collected."
            )
            .frame(height: InsightChartCanvas.hero)
            .padding(Space.xl)
            .contentCard()
            .padding(Space.gutter)
        }
        .preferredColorScheme(.dark)
    }

    #Preview("Dormant canvas · partial") {
        ZStack {
            Color.black.ignoresSafeArea()
            DormantSlotsCanvas(
                slotCount: 6,
                filledSlots: 2,
                legend: "2/6 SETS · 9/28 DAYS",
                spanFraction: 9.0 / 28.0,
                accessibilityLabel: "Signal building. 2 of 6 sets and 9 of 28 days collected."
            )
            .frame(height: InsightChartCanvas.hero)
            .padding(Space.xl)
            .contentCard()
            .padding(Space.gutter)
        }
        .preferredColorScheme(.dark)
    }

    #Preview("Dormant canvas · nearly qualified") {
        ZStack {
            Color.black.ignoresSafeArea()
            DormantSlotsCanvas(
                slotCount: 6,
                filledSlots: 5,
                legend: "5/6 SETS · 24/28 DAYS",
                spanFraction: 24.0 / 28.0,
                accessibilityLabel: "Signal building. 5 of 6 sets and 24 of 28 days collected."
            )
            .frame(height: InsightChartCanvas.hero)
            .padding(Space.xl)
            .contentCard()
            .padding(Space.gutter)
        }
        .preferredColorScheme(.dark)
    }

    #Preview("Dormant canvas · accessibility type") {
        ZStack {
            Color.black.ignoresSafeArea()
            DormantSlotsCanvas(
                slotCount: 4,
                filledSlots: 1,
                legend: "1/4 RECENT WORKOUTS",
                accessibilityLabel: "Signal building. 1 of 4 recent workouts completed."
            )
            .frame(height: InsightChartCanvas.hero)
            .padding(Space.xl)
            .contentCard()
            .padding(Space.gutter)
        }
        .environment(\.dynamicTypeSize, .accessibility2)
        .preferredColorScheme(.dark)
    }

    #Preview("Insight chart · hero line, light") {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            VStack(alignment: .leading, spacing: Space.sm) {
                InsightChartLegend(
                    items: [
                        InsightChartLegend.Item(label: "7-day load", color: Tint.primary),
                    ],
                    trailing: "LAST 28 DAYS"
                )

                Chart(GalleryDemo.trend) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Load", point.value)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Tint.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
                .chartXAxis { InsightChartAxis.dates() }
                .chartYAxis { InsightChartAxis.counts() }
                .frame(height: InsightChartCanvas.hero)
            }
            .padding(Space.xl)
            .contentCard()
            .padding(Space.gutter)
        }
        .preferredColorScheme(.light)
    }
#endif
