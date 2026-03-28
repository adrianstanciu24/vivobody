import SwiftUI

// MARK: - PR Section

extension WorkoutCompleteView {
    struct PRRecord: Identifiable {
        let id: String
        let exercise: String
        let detail: String
        let weight: String
    }

    static let prRecords: [PRRecord] = [
        PRRecord(
            id: "pr1",
            exercise: "Barbell Bench Press",
            detail: "06 reps @ 205 lb · RIR 0 · prev 195 lb",
            weight: "205"
        ),
        PRRecord(id: "pr2", exercise: "Incline DB Press", detail: "08 reps @ 80 lb · RIR 1 · prev 75 lb", weight: "80")
    ]

    var prSection: some View {
        VStack(spacing: 0) {
            Text("PERSONAL RECORDS · 02 NEW")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.top, 16)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Self.prRecords) { pr in
                    prRow(pr)
                }
            }
            .padding(.horizontal, VivoSpacing.screenH)
            .padding(.bottom, 8)
        }
    }

    func prRow(_ pr: PRRecord) -> some View {
        HStack(spacing: 10) {
            Text("NEW PR")
                .font(.vivoMono(VivoFont.monoTiny))
                .tracking(VivoTracking.tight)
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: VivoRadius.badge)
                        .fill(Color.vivoGreen)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(pr.exercise)
                    .font(.vivoDisplay(VivoFont.caption))
                    .foregroundStyle(Color.vivoPrimary)
                Text(pr.detail)
                    .font(.vivoMono(VivoFont.monoSM))
                    .foregroundStyle(Color.vivoSecondary)
            }

            Spacer()

            Text(pr.weight)
                .font(.vivoDisplay(VivoFont.body, weight: .bold))
                .foregroundStyle(Color.vivoGreen)
        }
        .frame(height: 52)
    }
}

// MARK: - Muscle Volume

extension WorkoutCompleteView {
    struct MuscleVolume: Identifiable {
        let id: String
        let name: String
        let percentage: Double
        let label: String
    }

    static let muscleVolumes: [MuscleVolume] = [
        MuscleVolume(id: "m1", name: "CHEST", percentage: 0.62, label: "62%"),
        MuscleVolume(id: "m2", name: "SHOULDERS", percentage: 0.21, label: "21%"),
        MuscleVolume(id: "m3", name: "TRICEPS", percentage: 0.12, label: "12%"),
        MuscleVolume(id: "m4", name: "CORE", percentage: 0.05, label: "5%")
    ]

    var muscleVolumeSection: some View {
        VStack(spacing: 0) {
            Text("MUSCLE VOLUME SPLIT")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.top, 16)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Self.muscleVolumes) { muscle in
                    muscleBar(muscle)
                }
            }
            .padding(.horizontal, VivoSpacing.screenH)
            .padding(.bottom, 8)
        }
    }

    func muscleBar(_ muscle: MuscleVolume) -> some View {
        HStack(spacing: 10) {
            Text(muscle.name)
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.normal)
                .foregroundStyle(Color.vivoSecondary)
                .frame(width: 72, alignment: .leading)

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: VivoRadius.badge)
                    .fill(Color.vivoSurface)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: VivoRadius.badge)
                            .fill(Color.vivoAccent)
                            .frame(width: proxy.size.width * muscle.percentage)
                    }
            }
            .frame(height: 8)

            Text(muscle.label)
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.tight)
                .foregroundStyle(Color.vivoSecondary)
                .frame(width: 30, alignment: .trailing)
        }
        .frame(height: 29)
    }
}

// MARK: - Comparison Section

extension WorkoutCompleteView {
    struct ComparisonRow: Identifiable {
        let id: String
        let label: String
        let today: String
        let previous: String
    }

    static let comparisons: [ComparisonRow] = [
        ComparisonRow(id: "c1", label: "VOLUME", today: "14,820 lb", previous: "13,580 lb"),
        ComparisonRow(id: "c2", label: "DURATION", today: "52 min", previous: "55 min"),
        ComparisonRow(id: "c3", label: "SETS", today: "22 sets", previous: "22 sets"),
        ComparisonRow(id: "c4", label: "AVG RIR", today: "2.1 avg", previous: "2.4 avg"),
        ComparisonRow(id: "c5", label: "PRs", today: "02 PRs", previous: "01 PR")
    ]

    var comparisonSection: some View {
        VStack(spacing: 0) {
            Text("VS LAST SESSION · MAR 11")
                .font(.vivoMono(VivoFont.monoSM))
                .tracking(VivoTracking.wide)
                .foregroundStyle(Color.vivoMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VivoSpacing.screenH)
                .padding(.top, 16)
                .padding(.bottom, 10)

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("TODAY")
                        .font(.vivoMono(VivoFont.monoTiny))
                        .tracking(VivoTracking.normal)
                        .foregroundStyle(Color.vivoMuted)
                        .frame(height: 22)
                    ForEach(Self.comparisons) { row in
                        Text(row.today)
                            .font(.vivoMono(VivoFont.monoCaption))
                            .foregroundStyle(Color.vivoPrimary)
                            .frame(height: 33)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .center, spacing: 0) {
                    Color.clear.frame(height: 22)
                    ForEach(Self.comparisons) { row in
                        Text(row.label)
                            .font(.vivoMono(VivoFont.monoTiny))
                            .tracking(VivoTracking.normal)
                            .foregroundStyle(Color.vivoMuted)
                            .frame(height: 33)
                    }
                }
                .frame(width: 72)

                VStack(alignment: .trailing, spacing: 0) {
                    Text("MAR 11")
                        .font(.vivoMono(VivoFont.monoTiny))
                        .tracking(VivoTracking.normal)
                        .foregroundStyle(Color.vivoMuted)
                        .frame(height: 22)
                    ForEach(Self.comparisons) { row in
                        Text(row.previous)
                            .font(.vivoMono(VivoFont.monoCaption))
                            .foregroundStyle(Color.vivoSecondary)
                            .frame(height: 33)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, VivoSpacing.screenH)
            .padding(.bottom, 8)
        }
    }
}
