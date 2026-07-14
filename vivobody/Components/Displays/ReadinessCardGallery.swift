#if DEBUG
//
//  ReadinessCardGallery.swift
//  vivobody
//
//  Every voice the placard can wear: trained today at productive
//  load, a high week, a light week, and the forming period before
//  the personal range exists (provisional gauge marker).
//

import VivoKit
import SwiftUI

struct ReadinessCardGallery: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xxl) {
                header

                labelled("Trained today · productive") {
                    ReadinessCard(
                        report: Self.report(loads: [3, 0, 4, 0, 0, 5, 4], ratio: 1.0, verdict: .productive),
                        line: ReadinessLine(lead: "Today's in the bank.", tail: "Recover well.")
                    )
                }

                labelled("High load") {
                    ReadinessCard(
                        report: Self.report(loads: [5, 6, 0, 7, 6, 8, 0], ratio: 1.6, verdict: .high),
                        line: ReadinessLine(lead: "Training load is high.", tail: "Keep today lighter.")
                    )
                }

                labelled("Light week") {
                    ReadinessCard(
                        report: Self.report(loads: [0, 2, 0, 0, 0, 3, 0], ratio: 0.5, verdict: .low),
                        line: ReadinessLine(lead: "Load is lighter lately.", tail: "Build when ready.")
                    )
                }

                labelled("Forming · no range yet") {
                    ReadinessCard(
                        report: Self.report(loads: [0, 0, 4, 0, 3, 0, 0], ratio: 1.1, verdict: .insufficient),
                        line: ReadinessLine(lead: "Fresh — 2 days' rest.", tail: "Good to go.")
                    )
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.top, Space.section)
            .padding(.bottom, Space.xxl)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("READINESS CARD")
                .font(Typography.metricMicro)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
            Text("The verdict, drawn.")
                .font(Typography.display)
                .foregroundStyle(.white)
            Text("Seven days of work as bars, today in the verdict colour, and where the rolling week sits against your productive range.")
                .font(Typography.sectionLabel)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 2)
        }
    }

    private func labelled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(title.uppercased())
                .font(Typography.metricMicro)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.35))
            content()
        }
    }

    /// Fabricated report: `loads` are per-day hard-set equivalents,
    /// oldest first and ending today.
    private static func report(
        loads: [Double],
        ratio: Double,
        verdict: LoadVerdict
    ) -> TrainingLoadReport {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = loads.enumerated().compactMap { index, load -> DayLoad? in
            guard let date = calendar.date(byAdding: .day, value: index - (loads.count - 1), to: today) else {
                return nil
            }
            return DayLoad(date: date, load: load)
        }
        return TrainingLoadReport(
            currentLoad: loads.reduce(0, +),
            usualLoad: verdict == .insufficient ? nil : 12,
            ratio: verdict == .insufficient ? 0 : ratio,
            provisionalRatio: verdict == .insufficient ? ratio : nil,
            verdict: verdict,
            daysLogged: verdict == .insufficient ? 10 : 60,
            points: [],
            recentDays: days,
            drivers: .empty
        )
    }
}

#Preview("Readiness Card") {
    ReadinessCardGallery()
        .preferredColorScheme(.dark)
}

#endif
