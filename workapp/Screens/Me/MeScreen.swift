//
//  MeScreen.swift
//  workapp
//
//  Personal tab. Two stacked surfaces:
//    • YOUR JOURNEY — lifetime totals across all archived sessions
//      (workouts logged, sets completed, total volume).
//    • PREFERENCES — defaultable rest seconds, haptics on/off.
//
//  Settings persist via @AppStorage (UserDefaults). The Haptics
//  engine reads its enabled flag directly from UserDefaults on every
//  emission, so toggling here takes effect immediately throughout
//  the app with no extra wiring.
//
//  Units (lb/kg) intentionally NOT in this first cut — proper unit
//  support requires conversion through NumberScrubber and ~14 display
//  sites, which deserves its own focused session.
//

import SwiftUI
import SwiftData

struct MeScreen: View {
    @Bindable var appState: AppState

    /// All archived sessions. Drives the stats header — we sum
    /// across the full set rather than relying on cached counters,
    /// so the totals stay correct after any edit/delete in History.
    @Query(
        filter: #Predicate<WorkoutSession> { $0.completedAt != nil }
    )
    private var completedSessions: [WorkoutSession]

    @AppStorage(SettingsKey.hapticsEnabled)
    private var hapticsEnabled: Bool = SettingsDefaults.hapticsEnabled

    @AppStorage(SettingsKey.defaultRestSeconds)
    private var defaultRestSeconds: Int = SettingsDefaults.defaultRestSeconds

    /// Common rest values that cover the bulk of strength-training
    /// programs. Surfaced as a horizontal chip selector — picking a
    /// value is a single tap with no keyboard or sheet round-trip.
    private let restOptions: [Int] = [30, 60, 90, 120, 180]

    /// Recognizable "complete" green used elsewhere in the app
    /// (summary card accent, complete-state set rows). Re-used here
    /// for the Haptics toggle so its ON state has clear contrast
    /// against the white thumb rather than reading as a blank pill.
    private let toggleOnGreen = Color(.sRGB, red: 0.36, green: 0.92, blue: 0.62, opacity: 1.0)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                statsSection
                preferencesSection
                footer
            }
            .padding(.horizontal, 22)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("YOUR JOURNEY")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.50))
                Spacer()
                if !completedSessions.isEmpty {
                    Text("ALL TIME")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            HStack(spacing: 0) {
                statBlock(value: "\(totalWorkouts)", unit: nil, label: "WORKOUTS")
                statDivider
                statBlock(value: "\(totalSets)", unit: nil, label: "SETS")
                statDivider
                statBlock(value: volumeLabel, unit: "lb", label: "VOLUME")
            }
            .padding(.vertical, 6)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func statBlock(value: String, unit: String?, label: String) -> some View {
        VStack(spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 0.5, height: 40)
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PREFERENCES")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.50))

            VStack(alignment: .leading, spacing: 18) {
                restRow
                rowDivider
                hapticsRow
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }

    private var restRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Default Rest")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Between sets — used by the rest timer")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Text("\(defaultRestSeconds)s")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(restOptions, id: \.self) { seconds in
                        restChip(seconds: seconds)
                    }
                }
            }
        }
    }

    private func restChip(seconds: Int) -> some View {
        let isSelected = defaultRestSeconds == seconds
        return Button {
            Haptics.selection()
            defaultRestSeconds = seconds
        } label: {
            Text("\(seconds)s")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.75))
                .frame(minWidth: 56)
                .padding(.vertical, 9)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.white : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0 : 0.10), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(seconds) second rest")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var hapticsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Haptics")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Taps and patterns throughout the app")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { hapticsEnabled },
                set: { newValue in
                    hapticsEnabled = newValue
                    if newValue {
                        // The @AppStorage write propagates synchronously
                        // to UserDefaults, so the next Haptics emission
                        // reads `true` — this soft tap plays as a
                        // confirmation that haptics just came back on.
                        Haptics.soft()
                    }
                }
            ))
            .labelsHidden()
            .tint(toggleOnGreen)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            Text("workapp")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.30))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Derived

    private var totalWorkouts: Int { completedSessions.count }

    private var totalSets: Int {
        completedSessions.reduce(0) { $0 + $1.totalSets }
    }

    private var totalVolume: Double {
        completedSessions.reduce(0) { $0 + $1.totalVolume }
    }

    /// Volume label tuned for the lifetime totals card. Numbers
    /// below 10k stay readable in full ("9,847"). At and beyond 10k,
    /// they compact to "12.3k" / "48.9k" so the value column never
    /// wraps under the 3-stat grid's tight per-column width.
    private var volumeLabel: String {
        if totalVolume >= 10_000 {
            let k = totalVolume / 1000
            // Drop the trailing .0 for clean values (50k, not 50.0k).
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))k"
                : String(format: "%.1fk", k)
        }
        return Self.volumeFormatter.string(from: NSNumber(value: Int(totalVolume))) ?? "\(Int(totalVolume))"
    }

    private static let volumeFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f
    }()
}

#Preview {
    NavigationStack {
        MeScreen(appState: AppState())
            .navigationTitle("Me")
    }
    .preferredColorScheme(.dark)
}
