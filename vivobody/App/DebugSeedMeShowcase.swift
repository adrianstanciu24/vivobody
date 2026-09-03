//
//  DebugSeedMeShowcase.swift
//  vivobody
//
//  Deterministic populated Me-dashboard fixture: the compact Insights history
//  supplies journey, milestone, record, and recap data, while a bounded weight
//  series exercises latest-value, delta, and sparkline presentation.
//

import Foundation
import SwiftData

#if DEBUG

    @MainActor
    enum MeShowcaseSeed {
        static func seed(
            in context: ModelContext,
            now: Date = Date(),
            calendar: Calendar = .current
        ) {
            InsightsShowcaseSeed.seed(
                in: context,
                now: now,
                calendar: calendar
            )

            let existing = (try? context.fetch(
                FetchDescriptor<BodyWeightEntry>()
            )) ?? []
            guard existing.isEmpty else { return }

            let samples: [(daysAgo: Int, canonicalPounds: Double)] = [
                (14, 180.0),
                (7, 178.8),
                (0, 177.6),
            ]
            for sample in samples {
                guard let day = calendar.date(
                    byAdding: .day,
                    value: -sample.daysAgo,
                    to: calendar.startOfDay(for: now)
                ), let sevenAM = calendar.date(
                    bySettingHour: 7,
                    minute: 0,
                    second: 0,
                    of: day
                ) else { continue }
                let date = min(sevenAM, now)
                context.insert(BodyWeightEntry(
                    date: date,
                    weight: sample.canonicalPounds
                ))
            }
            try? context.saveOrRollback()
        }
    }

#endif
