//
//  HistoryDateGroupSection.swift
//  vivobody
//
//  One date bucket of the History log and the session rows inside it.
//  Extracted from HistoryComponents.swift.
//

import SwiftUI
import VivoKit

// MARK: - Date group section

/// One date bucket as a ledger block: the `SectionHeader` stays on
/// black, the bucket's rows sit together inside a single content
/// card with inset hairlines between them. Today's card uses the
/// bright surface so the freshest sessions lift off the screen.
struct DateGroupSection: View {
    let group: HistoryDateGroup
    let unit: WeightUnit
    let prSessions: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            SectionHeader(title: group.title, trailing: group.subtitle)

            VStack(spacing: 0) {
                ForEach(Array(group.sessions.enumerated()), id: \.element.id) { index, session in
                    if index > 0 { rowDivider }
                    NavigationLink {
                        SessionDetailScreen(session: session)
                    } label: {
                        SessionRow(
                            session: session,
                            unit: unit,
                            hasPR: prSessions.contains(session.id),
                            prominent: group.style == .rich
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens workout details")
                }
            }
            .contentCard(bright: group.style == .rich)
        }
    }

    /// In-card hairline between rows, inset so it never runs into
    /// the card's rounded corners.
    var rowDivider: some View {
        Rectangle()
            .fill(Surface.edge)
            .frame(height: 0.5)
            .padding(.horizontal, Space.lg)
            .accessibilityHidden(true)
    }
}

// MARK: - Session row

/// One archived session as a row inside a date-group card. The left
/// column carries identity (a workout title for today, a date for
/// earlier sessions) plus a muscle/time meta line; the right column
/// anchors its honest receipt metric in monospace. `prominent` (today's
/// sessions) enlarges the numeral and promotes the title. A PR adds
/// the lone accent: a small outlined tag beside the title.
struct SessionRow: View {
    let session: WorkoutSession
    let unit: WeightUnit
    let hasPR: Bool
    let prominent: Bool

    var muscleTags: [MuscleGroup] {
        session.distinctMuscleGroupsInOrder
    }

    var body: some View {
        let receiptMetric = session.primaryReceiptMetric(unit: unit)
        let receiptUnit: String? = receiptMetric.kind == .reps
            ? "reps"
            : receiptMetric.unit

        HStack(alignment: .center, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.xs) {
                HStack(spacing: Space.sm) {
                    Text(titleLine)
                        .font(prominent ? Typography.title : Typography.sectionHeading)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if hasPR { prBadge }
                }
                Text(metaLine)
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: Space.sm)

            // The receipt metric is supporting context, not the headline — kept a calm
            // grayscale numeral so the workout's identity (name + muscle
            // fingerprint) leads. The accent lives only in the rare PR
            // badge, never on every line.
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(receiptMetric.value + (receiptMetric.qualifier ?? ""))
                    .font(prominent ? Typography.statValue : Typography.metricInline)
                    .foregroundStyle(Ink.secondary)
                    .monospacedDigit()
                if let receiptUnit {
                    Text(receiptUnit)
                        .font(Typography.metricUnit)
                        .foregroundStyle(Ink.tertiary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(receiptMetric.accessibilityLabel)

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(Ink.quaternary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: prominent ? 72 : Space.rowMin, alignment: .leading)
        .padding(.horizontal, Space.lg)
        .padding(.vertical, Space.md)
        .contentShape(Rectangle())
        .accessibilityIdentifier("historySessionRow")
        .accessibilityElement(children: .combine)
    }

    /// The lone accent in the list: the shared outlined "PR" tag next
    /// to a session that set a new top weight. Replaces the old
    /// practice of flooding the whole volume numeral orange, which
    /// made every row shout.
    var prBadge: some View {
        PRTag()
    }

    /// Today's rows lead with the workout's muscle identity; earlier
    /// rows lead with their date.
    var titleLine: String {
        prominent ? workoutTitle : dateLine
    }

    /// Secondary line: the session's muscle fingerprint followed by
    /// the time it was logged. The fingerprint is what stops a column
    /// of "Full body" rows from reading as identical — you can see at
    /// a glance which regions each session actually hit — while the
    /// time distinguishes multiple sessions on the same day.
    var metaLine: String {
        "\(muscleFingerprint)  ·  \(timeString)"
    }

    var workoutTitle: String {
        switch muscleTags.count {
        case 0: "Workout"
        case 1: "\(muscleTags[0].displayName) day"
        case 2: "\(muscleTags[0].displayName) + \(muscleTags[1].displayName)"
        default: "Full body"
        }
    }

    /// Up to two muscle groups, in worked order, with a "+N" tail
    /// when the session spans more — capped short enough that the
    /// trailing time never truncates inside the card. Gives even a
    /// generic "Full body" row a legible signature of what was
    /// actually trained.
    var muscleFingerprint: String {
        let names = muscleTags.map(\.displayName)
        switch names.count {
        case 0: return "Workout"
        case 1, 2: return names.joined(separator: " · ")
        default: return names.prefix(2).joined(separator: " · ") + " +\(names.count - 2)"
        }
    }

    var dateLine: String {
        let date = session.completedAt ?? session.startedAt
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var timeString: String {
        let date = session.completedAt ?? session.startedAt
        return date.formatted(.dateTime.hour().minute())
    }
}
