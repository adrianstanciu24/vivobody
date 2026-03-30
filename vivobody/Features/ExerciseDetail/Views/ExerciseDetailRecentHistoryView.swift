import SwiftUI

struct ExerciseDetailRecentHistoryView: View {
    private static let sessions: [ExerciseHistorySession] = [
        ExerciseHistorySession(
            date: "MAR 15 · PUSH DAY",
            sets: [
                ExerciseHistorySet(reps: 8, weight: 185, isPR: false),
                ExerciseHistorySet(reps: 6, weight: 195, isPR: false),
                ExerciseHistorySet(reps: 3, weight: 205, isPR: false),
                ExerciseHistorySet(reps: 1, weight: 225, isPR: true)
            ]
        ),
        ExerciseHistorySession(
            date: "MAR 10 · UPPER BODY",
            sets: [
                ExerciseHistorySet(reps: 8, weight: 185, isPR: true),
                ExerciseHistorySet(reps: 8, weight: 175, isPR: false),
                ExerciseHistorySet(reps: 6, weight: 185, isPR: false)
            ]
        ),
        ExerciseHistorySession(
            date: "MAR 05 · PUSH DAY",
            sets: [
                ExerciseHistorySet(reps: 8, weight: 175, isPR: false),
                ExerciseHistorySet(reps: 6, weight: 185, isPR: false),
                ExerciseHistorySet(reps: 5, weight: 195, isPR: false)
            ]
        ),
        ExerciseHistorySession(
            date: "FEB 28 · PUSH DAY",
            sets: [
                ExerciseHistorySet(reps: 8, weight: 175, isPR: false),
                ExerciseHistorySet(reps: 5, weight: 195, isPR: false),
                ExerciseHistorySet(reps: 2, weight: 215, isPR: true)
            ]
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
            ForEach(Array(Self.sessions.enumerated()), id: \.offset) { index, session in
                ExerciseHistorySessionRow(session: session)
                if index < Self.sessions.count - 1 {
                    rowDivider
                }
            }
        }
        .padding(.horizontal, VivoSpacing.screenH)
        .padding(.vertical, 14)
    }

    private var sectionHeader: some View {
        HStack {
            Text("RECENT HISTORY")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
            Spacer()
            Text("SEE ALL ›")
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)
        }
        .padding(.bottom, VivoSpacing.itemGap)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.vivoSurface)
            .frame(height: 1)
    }
}

// MARK: - Data

struct ExerciseHistorySession {
    let date: String
    let sets: [ExerciseHistorySet]
}

struct ExerciseHistorySet: Identifiable {
    let id = UUID()
    let reps: Int
    let weight: Int
    let isPR: Bool
}

// MARK: - Session Row

struct ExerciseHistorySessionRow: View {
    let session: ExerciseHistorySession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.date)
                .font(.vivoMono(VivoFont.monoXS))
                .tracking(VivoTracking.medium)
                .foregroundStyle(Color.vivoSecondary)

            VivoFlowLayout(spacing: 6) {
                ForEach(session.sets) { exerciseSet in
                    exerciseSetPill(exerciseSet)
                }
            }
        }
        .padding(.vertical, VivoSpacing.tightGap)
    }

    private func exerciseSetPill(_ pill: ExerciseHistorySet) -> some View {
        Text("\(pill.reps)×\(pill.weight)")
            .font(.vivoMono(VivoFont.monoXS))
            .tracking(VivoTracking.tight)
            .foregroundStyle(pill.isPR ? Color.vivoBackground : Color.vivoPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: VivoRadius.badge)
                    .fill(pill.isPR ? Color.vivoAccent : Color.clear)
            )
            .overlay(
                pill.isPR ? nil :
                    RoundedRectangle(cornerRadius: VivoRadius.badge)
                    .stroke(Color.vivoSurface, lineWidth: 1)
            )
    }
}

#Preview {
    ExerciseDetailRecentHistoryView()
        .background(Color.vivoBackground)
}
