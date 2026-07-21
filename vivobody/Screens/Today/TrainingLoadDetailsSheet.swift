//
//  TrainingLoadDetailsSheet.swift
//  vivobody
//
//  The decoder behind Today's compact Training Load instrument. It
//  teaches the reading with the user's real seven-day receipt: count
//  completed working-set credit, total the rolling week, then compare
//  it with the user's own preceding weeks. The language deliberately
//  avoids recovery or injury claims; load is context, not a diagnosis.
//

import VivoKit
import SwiftUI

struct TrainingLoadDetailsSheet: View {
    let report: TrainingLoadReport

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: Space.section) {
                    hero
                    weekReceipt
                    setDecoder
                    personalRange
                    contextNote
                }
                .padding(.horizontal, Space.gutter)
                .padding(.top, Space.lg)
                .padding(.bottom, Space.section)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Load-bearing: pins the scroll content to the viewport
                // width. Without it the content measures wider than the
                // sheet and the vertical-only ScrollView pans sideways.
                .containerRelativeFrame(.horizontal)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .screenBackground()
            .navigationTitle("Training load")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Live reading

    /// A two-number instrument makes the comparison visible before any
    /// prose explains it. While the baseline forms, the right display
    /// stays honest instead of inventing a target.
    private var hero: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Your week, in context")
                .font(Typography.display)
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: Space.md) {
                heroMetric(
                    value: format(report.currentLoad),
                    label: "Last 7 days",
                    accent: true
                )

                Image(systemName: "arrow.right")
                    .font(Typography.title)
                    .foregroundStyle(Ink.quaternary)
                    .padding(.top, Space.md)
                    .accessibilityHidden(true)

                heroMetric(
                    value: report.usualLoad.map(format) ?? "—",
                    label: "Your usual",
                    accent: false
                )
            }

            Text(heroSummary)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.xl)
        .contentCard(bright: true)
        .accessibilityElement(children: .combine)
    }

    private func heroMetric(value: String, label: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(value)
                .font(Typography.metricLg)
                .foregroundStyle(accent ? Tint.primary : Ink.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .panelLegend()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroSummary: String {
        guard !report.points.isEmpty else {
            return "Complete a workout and your first seven-day reading will appear here."
        }
        guard let change = report.changeFromUsual else {
            if report.daysLogged < 28 {
                let remaining = 28 - report.daysLogged
                return "This is your current load. About \(remaining) more day\(remaining == 1 ? "" : "s") of history will help turn it into a personal comparison."
            }
            return "This is your current load. A stable comparison appears once at least three prior weeks contain training."
        }
        let percent = Int((abs(change) * 100).rounded())
        if percent <= 1 {
            return "Your last seven days match your usual training."
        }
        return "Your last seven days are \(percent)% \(change > 0 ? "above" : "below") your usual training."
    }

    // MARK: - Step 1: rolling receipt

    private var weekReceipt: some View {
        explainerSection(number: "01", title: "Count the last 7 days") {
            VStack(alignment: .leading, spacing: Space.lg) {
                dayBars
                Text("Each bar is one calendar day. Together they total \(format(report.currentLoad)) estimated hard-set equivalents. Tomorrow, the oldest day rolls out and the newest rolls in.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.xl)
            .contentCard()
        }
    }

    private static let barStripHeight: CGFloat = 54

    private var dayBars: some View {
        let days = displayedDays
        let peak = max(days.map(\.load).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: Space.sm) {
            ForEach(days) { day in
                VStack(spacing: Space.xs) {
                    Text(day.load > 0 ? format(day.load) : "·")
                        .font(Typography.metricMicro)
                        .foregroundStyle(day.load > 0 ? Ink.secondary : Ink.quaternary)
                        .monospacedDigit()

                    VStack {
                        Spacer(minLength: 0)
                        Capsule()
                            .fill(day.id == days.last?.id && day.load > 0 ? Tint.primary : barColor(day))
                            .frame(height: barHeight(day.load, peak: peak))
                    }
                    .frame(height: Self.barStripHeight)

                    Text(day.weekdayInitial())
                        .font(Typography.metricMicro)
                        .foregroundStyle(day.id == days.last?.id ? Ink.secondary : Ink.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Seven day training receipt totaling \(format(report.currentLoad)) estimated hard sets")
    }

    private var displayedDays: [DayLoad] {
        guard report.recentDays.isEmpty else { return report.recentDays }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map {
                DayLoad(date: $0, load: 0)
            }
        }
    }

    private func barHeight(_ load: Double, peak: Double) -> CGFloat {
        guard load > 0 else { return 3 }
        return max(10, Self.barStripHeight * CGFloat(load / peak))
    }

    private func barColor(_ day: DayLoad) -> Color {
        day.load > 0 ? Ink.tertiary : Surface.edge
    }

    // MARK: - Step 2: hard-set currency

    private var setDecoder: some View {
        explainerSection(number: "02", title: "Weigh the work") {
            VStack(alignment: .leading, spacing: Space.lg) {
                signalChain

                Text("A normal hard working set is about 1.0. The app gives less credit when a set is very short, light for you, or stopped far from failure.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    creditRow("Hard working set", value: "≈ 1.0", tint: Tint.primary)
                    rowDivider
                    creditRow("Short, light, or easy", value: "< 1.0", tint: Ink.secondary)
                    rowDivider
                    creditRow("Warm-up set", value: "0", tint: Ink.tertiary)
                }
                .padding(.horizontal, Space.lg)
                .contentChip()

                Text("Completed strength reps and timed strength holds count. Warm-ups and non-strength work stay in your log but do not raise this number.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// A compact signal path: the three independent reasons a working
    /// set may earn full or partial credit converge into one value.
    private var signalChain: some View {
        VStack(spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                signalChip("Effort")
                Text("×")
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
                signalChip("Reps / hold")
                Text("×")
                    .foregroundStyle(Ink.quaternary)
                    .accessibilityHidden(true)
                signalChip("Relative load")
            }

            HStack(spacing: Space.sm) {
                Rectangle()
                    .fill(Surface.edge)
                    .frame(height: 1)
                Circle()
                    .fill(Tint.primary)
                    .frame(width: 9, height: 9)
                    .shadow(color: Tint.primary.opacity(0.45), radius: 5)
                Text("Set credit")
                    .panelLegend()
                    .fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Set credit combines effort, reps or hold duration, and load relative to your own strength")
    }

    private func signalChip(_ label: String) -> some View {
        Text(label)
            .panelLegend()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, Space.sm)
            .frame(minHeight: 32)
            .frame(maxWidth: .infinity)
            .background(Surface.cardTintBright, in: Capsule())
    }

    private func creditRow(_ label: String, value: String, tint: Color) -> some View {
        HStack(spacing: Space.md) {
            Text(label)
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
            Spacer(minLength: Space.sm)
            Text(value)
                .font(Typography.metricInline)
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(minHeight: Space.rowMin)
        .accessibilityElement(children: .combine)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
    }

    // MARK: - Step 3: personal range

    private var personalRange: some View {
        explainerSection(number: "03", title: "Compare with you") {
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(spacing: Space.sm) {
                    SegmentGauge(segments: 48, height: 12, spacing: 2) { _, position in
                        ReadinessCard.gaugeSegmentColor(at: position, for: report)
                    }

                    HStack {
                        Text("Low")
                        Spacer()
                        Text("Productive")
                        Spacer()
                        Text("High")
                    }
                    .panelLegend()
                }

                Text(rangeExplanation)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let range = report.productiveRange {
                    StatStrip(
                        stats: [
                            Stat(value: format(range.lowerBound), label: "Low edge"),
                            Stat(value: format(report.currentLoad), label: "Your week", accent: true),
                            Stat(value: format(range.upperBound), label: "High edge"),
                        ],
                        valueFont: Typography.metricInline
                    )
                }
            }
            .padding(Space.xl)
            .contentCard()
        }
    }

    private var rangeExplanation: String {
        if report.hasEnoughHistory {
            return "Your usual load is the middle of the four weeks before this one. Productive means your rolling week is 80–130% of that personal baseline—not somebody else's target."
        }
        if report.daysLogged < 28 {
            let remaining = 28 - report.daysLogged
            return "The marker is provisional while your pattern forms. After about \(remaining) more day\(remaining == 1 ? "" : "s")—and at least three active prior weeks—the app can show a stable personal range."
        }
        return "The marker is provisional while your pattern forms. Once at least three of the prior four weeks contain training, the app can show a stable personal range."
    }

    private var statusColor: Color {
        ReadinessCard.statusColor(for: report)
    }

    // MARK: - Interpretation

    private var contextNote: some View {
        HStack(alignment: .top, spacing: Space.md) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Context, not a warning")
                    .font(Typography.headline)
                    .foregroundStyle(Ink.primary)
                Text("High does not predict injury, and low does not mean failure. The reading only shows how quickly your recent work changed relative to your own pattern. Use it to make increases gradual and recovery deliberate.")
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Space.xl)
        .contentCard(tint: statusColor)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Shared presentation

    private func explainerSection<Content: View>(
        number: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                Text(number)
                    .font(Typography.metricMicro)
                    .foregroundStyle(Tint.primary)
                    .monospacedDigit()
                Text(title)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            content()
        }
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }
}

#Preview("Training load details") {
    TrainingLoadDetailsSheet(
        report: TrainingLoadReport(
            currentLoad: 17.5,
            usualLoad: 15,
            ratio: 17.5 / 15,
            provisionalRatio: nil,
            verdict: .productive,
            daysLogged: 60,
            points: [
                LoadPoint(date: Date(), load: 17.5, productiveLower: 12, productiveUpper: 19.5)
            ],
            recentDays: (0..<7).compactMap { offset in
                Calendar.current.date(byAdding: .day, value: offset - 6, to: Date()).map {
                    DayLoad(date: $0, load: [3, 0, 4, 0, 2.5, 5, 3][offset])
                }
            },
            drivers: .empty
        )
    )
    .preferredColorScheme(.dark)
}
