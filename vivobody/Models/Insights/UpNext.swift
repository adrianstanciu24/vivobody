//
//  UpNext.swift
//  vivobody
//
//  The Today "Up next" recommendation, driven by the weekday schedule
//  the user pins to each template. It answers one question: what's the
//  next workout, and when is it due?
//
//  Walking forward from today, the first weekday that carries a
//  scheduled template wins; its distance becomes the "Today / Tomorrow
//  / in N days" label. Today is only offered as a startable workout
//  when it's a scheduled day and nothing has been logged yet — any
//  completed session today satisfies the day, so the card rolls on to
//  the next one. When recent load is high the scheduled day still
//  stands, just flagged to keep the session lighter.
//
//  Pure value-type computation on injected dates (see `UpNextTests`).
//  Holds live `WorkoutTemplate` references, so it's main-actor work
//  read during `body`, never sent across actors.
//

import Foundation

struct UpNext {
    enum RestReason: Equatable {
        /// Today simply isn't a scheduled training day.
        case offDay
        /// A workout was already logged today.
        case doneToday
    }

    enum Kind {
        /// Train today: a scheduled template with nothing logged yet.
        /// `more` counts other templates also pinned to today;
        /// `easeOff` flags a high recent training load.
        case scheduled(template: WorkoutTemplate, more: Int, easeOff: Bool)
        /// Today is a rest day; the next scheduled template sits
        /// `daysUntil` days out (nil only if the schedule somehow
        /// resolves to nothing, which a full week can't).
        case rest(reason: RestReason, next: WorkoutTemplate?, daysUntil: Int, more: Int)
        /// No template is pinned to any weekday — nothing to suggest.
        case unscheduled
    }

    let kind: Kind

    /// Whether there's anything to show on Today. Unscheduled (no
    /// pinned days) and a rest with no resolvable next both hide.
    var isPresentable: Bool {
        switch kind {
        case .scheduled:                 return true
        case .rest(_, let next, _, _):   return next != nil
        case .unscheduled:               return false
        }
    }

    static func compute(
        templates: [WorkoutTemplate],
        sessions: [WorkoutSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> UpNext {
        let scheduled = templates.filter(\.isScheduled)
        guard !scheduled.isEmpty else { return UpNext(kind: .unscheduled) }

        let today = calendar.startOfDay(for: now)
        let trainedToday = sessions.contains { session in
            calendar.isDate(session.completedAt ?? session.startedAt, inSameDayAs: now)
        }

        // Templates pinned to the weekday `offset` days from today,
        // least-recently-used first so same-day picks rotate.
        func pinned(at offset: Int) -> [WorkoutTemplate] {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return [] }
            let weekday = calendar.component(.weekday, from: day)
            return scheduled.filter { $0.isScheduled(on: weekday) }.sorted(by: rotationOrder)
        }

        // Train today — a scheduled day with nothing logged yet.
        let todays = pinned(at: 0)
        if !trainedToday, let pick = todays.first {
            let easeOff = sessions.trainingLoad(now: now, calendar: calendar).verdict == .high
            return UpNext(kind: .scheduled(template: pick, more: todays.count - 1, easeOff: easeOff))
        }

        // Today is a rest day (off the schedule, or already trained).
        // Offsets 1...7 cover every weekday exactly once, so a non-empty
        // schedule always resolves here.
        let reason: RestReason = trainedToday ? .doneToday : .offDay
        for offset in 1...7 {
            let day = pinned(at: offset)
            if let next = day.first {
                return UpNext(kind: .rest(reason: reason, next: next, daysUntil: offset, more: day.count - 1))
            }
        }

        return UpNext(kind: .unscheduled)
    }

    /// Least-recently-used first: never-used templates lead, then by
    /// oldest `lastUsedAt`, then Library order.
    private nonisolated static func rotationOrder(_ a: WorkoutTemplate, _ b: WorkoutTemplate) -> Bool {
        switch (a.lastUsedAt, b.lastUsedAt) {
        case let (x?, y?):   return x < y
        case (nil, .some):   return true
        case (.some, nil):   return false
        case (nil, nil):     return a.sortOrder < b.sortOrder
        }
    }
}
