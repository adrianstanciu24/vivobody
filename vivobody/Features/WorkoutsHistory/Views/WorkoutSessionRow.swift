import SwiftUI

struct WorkoutSessionRow: View {
    let session: HistorySession
    var highlight = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                WorkoutSessionDateColumn(session: session)
                    .frame(width: 72)

                WorkoutSessionDetails(session: session)

                Spacer()

                WorkoutSessionTrailing(session: session)
            }
            .padding(.vertical, 14)
            .frame(minHeight: session.prCount > 0 ? 120 : 96)
            .background(highlight ? Color.vivoAccent.opacity(0.04) : .clear)
            .overlay(alignment: .leading) {
                if highlight {
                    Rectangle()
                        .fill(Color.vivoAccent)
                        .frame(width: 3)
                        .padding(.leading, 20)
                }
            }

            Rectangle()
                .fill(Color.vivoSurface)
                .frame(height: 1)
                .padding(.horizontal, VivoSpacing.screenH)
        }
    }
}

// MARK: - Date Column

struct WorkoutSessionDateColumn: View {
    let session: HistorySession

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(session.dayNumber)
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)

            Text(session.dayName)
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .tracking(VivoTracking.normal)
                .foregroundStyle(Color.vivoSecondary)

            Text(session.date)
                .font(.vivoMono(VivoFont.body, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
        }
        .padding(.leading, VivoSpacing.screenH)
    }
}

// MARK: - Session Details

struct WorkoutSessionDetails: View {
    let session: HistorySession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.name)
                .font(.vivoDisplay(VivoFont.body, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)

            Text(session.muscles)
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)

            WorkoutSessionStatsLine(session: session)

            if session.prCount > 0 {
                PRBadge(count: session.prCount)
            }
        }
    }
}

// MARK: - Stats Line

struct WorkoutSessionStatsLine: View {
    let session: HistorySession

    var body: some View {
        HStack(spacing: 0) {
            Text(session.duration)
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(" \u{00B7} ")
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)
            Text(session.volume)
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
            Text(" \u{00B7} ")
                .font(.vivoMono(VivoFont.monoSM))
                .foregroundStyle(Color.vivoMuted)
            Text(session.sets)
                .font(.vivoMono(VivoFont.monoSM, weight: .bold))
                .foregroundStyle(Color.vivoPrimary)
        }
    }
}

// MARK: - Trailing (Checkmark + Time)

struct WorkoutSessionTrailing: View {
    let session: HistorySession

    var body: some View {
        VStack(spacing: 4) {
            Text("\u{2713}")
                .font(.vivoDisplay(VivoFont.bodySmall))
                .foregroundStyle(Color.vivoGreen)
            Text(session.timeAgo)
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)
        }
        .padding(.trailing, VivoSpacing.screenH)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        WorkoutSessionRow(
            session: HistorySession(
                id: "p1", dayNumber: "03", dayName: "WED", date: "18",
                name: "Upper Body Push",
                muscles: "6 exercises \u{00B7} chest, delts, triceps",
                duration: "52:10", volume: "14,820 lb", sets: "22 sets",
                prCount: 2, timeAgo: "2h ago"
            ),
            highlight: true
        )
        WorkoutSessionRow(
            session: HistorySession(
                id: "p2", dayNumber: "02", dayName: "TUE", date: "17",
                name: "Lower Body",
                muscles: "6 exercises \u{00B7} quads, hams, glutes",
                duration: "52:10", volume: "8,420 lb", sets: "20 sets",
                prCount: 0, timeAgo: "Yesterday"
            )
        )
    }
    .background(Color.vivoBackground)
}
