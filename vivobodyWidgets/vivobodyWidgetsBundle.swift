//
//  vivobodyWidgetsBundle.swift
//  vivobodyWidgets
//
//  WidgetKit entry point for vivobody's glanceable surfaces. The
//  detailed layouts are implemented in follow-up files; this bundle
//  establishes the four requested widget registrations.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct vivobodyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        UpNextWidget()
        ConsistencyWidget()
        SignatureWidget()
        ActiveWorkoutLiveActivity()
        StartWorkoutControl()
    }
}

// MARK: - Timeline plumbing

struct SnapshotEntry<Snapshot>: TimelineEntry {
    let date: Date
    let snapshot: Snapshot
}

struct SnapshotProvider<Snapshot: Codable>: TimelineProvider {
    let key: String
    let fallback: Snapshot
    let refreshInterval: TimeInterval

    func placeholder(in context: Context) -> SnapshotEntry<Snapshot> {
        SnapshotEntry(date: Date(), snapshot: fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry<Snapshot>) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: readSnapshot() ?? fallback))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry<Snapshot>>) -> Void) {
        let now = Date()
        let entry = SnapshotEntry(date: now, snapshot: readSnapshot() ?? fallback)
        let next = now.addingTimeInterval(refreshInterval)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func readSnapshot() -> Snapshot? {
        guard
            let defaults = UserDefaults(suiteName: WidgetShared.appGroup),
            let data = defaults.data(forKey: key)
        else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}

// MARK: - Up Next

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetShared.upNextKind,
            provider: SnapshotProvider(
                key: WidgetShared.upNextSnapshotKey,
                fallback: UpNextSnapshot.placeholder,
                refreshInterval: 30 * 60
            )
        ) { entry in
            UpNextWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Up Next")
        .description("Today's scheduled workout or the next rest-day target.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct UpNextWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: UpNextSnapshot

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circular
            case .accessoryRectangular:
                rectangular
            case .accessoryInline:
                Text(inlineText)
            default:
                system
            }
        }
        .widgetURL(URL(string: "vivobody://today"))
        .containerBackground(.black, for: .widget)
    }

    private var system: some View {
        Group {
            switch family {
            case .systemSmall:
                smallSystem
            case .systemMedium:
                mediumSystem
            case .systemLarge:
                largeSystem
            default:
                smallSystem
            }
        }
        .padding()
    }

    private var smallSystem: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            kicker
            Spacer(minLength: Space.xs)
            Text(title)
                .font(Typography.display)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.68)
            Text(subtitle)
                .font(Typography.metricInline)
                .foregroundStyle(Ink.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }

    private var mediumSystem: some View {
        HStack(alignment: .top, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.sm) {
                kicker
                Text(title)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(subtitle)
                    .font(Typography.metricInline)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if snapshot.kind == .rest {
                restSummary
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                WidgetExerciseRows(exercises: snapshot.exercises, limit: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var largeSystem: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            kicker
            Text(title)
                .font(Typography.display)
                .foregroundStyle(Ink.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            if snapshot.kind == .rest {
                WidgetGlassPanel {
                    restSummary
                }
            } else {
                WidgetExerciseRows(exercises: snapshot.exercises, limit: 7)
                if let readiness = snapshot.readinessPhrase {
                    Text(readiness)
                        .font(Typography.body)
                        .foregroundStyle(snapshot.easeOff ? Tint.primary : Ink.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
            }

            Spacer(minLength: Space.xs)

            WidgetStatStrip(
                stats: [
                    WidgetStat(value: "\(snapshot.totalSets)", label: "Sets", accent: snapshot.kind == .scheduled),
                    WidgetStat(value: WidgetFormat.volumeValue(snapshot.totalVolume), unit: WidgetFormat.volumeUnit, label: "Volume"),
                    WidgetStat(value: "\(snapshot.exerciseCount)", label: "Exercises"),
                ]
            )

            if snapshot.kind == .scheduled {
                startButton
            }
        }
    }

    private var kicker: some View {
        HStack(spacing: Space.sm) {
            Text("Today")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
            if snapshot.kind == .scheduled {
                Circle()
                    .fill(Tint.primary)
                    .frame(width: 7, height: 7)
                    .accessibilityHidden(true)
            }
            if snapshot.easeOff {
                Text("Ease off")
                    .font(Typography.caption)
                    .foregroundStyle(Tint.primary)
                    .lineLimit(1)
            }
        }
    }

    private var restSummary: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(snapshot.readinessPhrase ?? "Recover well.")
                .font(Typography.body)
                .foregroundStyle(Ink.secondary)
                .lineLimit(3)
            if let next = snapshot.nextTemplateName {
                Text("Next: \(next) \(dayLabel(snapshot.daysUntil))")
                    .font(Typography.metricInline)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(2)
            }
        }
    }

    private var startButton: some View {
        Button(intent: StartTodaysWorkoutIntent()) {
            Text("Start")
                .font(Typography.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Space.tapMin)
        }
        .buttonStyle(.glassProminent)
        .tint(Tint.primary)
        .foregroundStyle(Tint.onAccent)
    }

    private var circular: some View {
        VStack(spacing: 3) {
            Circle()
                .fill(snapshot.kind == .scheduled ? Tint.primary : Ink.secondary)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(circularText)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Today")
                .font(Typography.micro)
                .foregroundStyle(Ink.tertiary)
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
            Text(subtitle)
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.secondary)
                .lineLimit(1)
        }
    }

    private var title: String {
        switch snapshot.kind {
        case .scheduled:
            return snapshot.templateName ?? "Workout"
        case .rest:
            return "Rest"
        case .unscheduled:
            return "Start fresh"
        }
    }

    private var subtitle: String {
        switch snapshot.kind {
        case .scheduled:
            return "\(snapshot.totalSets) \(snapshot.totalSets == 1 ? "set" : "sets")"
        case .rest:
            let next = snapshot.nextTemplateName ?? "workout"
            return "Next: \(next) \(dayLabel(snapshot.daysUntil))"
        case .unscheduled:
            return "No schedule"
        }
    }

    private var inlineText: String { "\(title) - \(subtitle)" }
    private var circularText: String { title == "Rest" ? "Rest" : String(title.prefix(6)) }

    private func dayLabel(_ days: Int) -> String {
        switch days {
        case 1: return "tomorrow"
        case 2...6: return "in \(days)d"
        default: return "next week"
        }
    }
}

// MARK: - Consistency

struct ConsistencyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetShared.consistencyKind,
            provider: SnapshotProvider(
                key: WidgetShared.consistencySnapshotKey,
                fallback: ConsistencySnapshot.placeholder,
                refreshInterval: 24 * 60 * 60
            )
        ) { entry in
            ConsistencyWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Consistency")
        .description("Your training streak and six-month heatmap.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct ConsistencyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: ConsistencySnapshot

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                VStack(spacing: 0) {
                    Text("\(snapshot.weekStreak)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                    Text("wks")
                        .font(Typography.micro)
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(snapshot.weekStreak) weeks")
                        .font(Typography.headline)
                    cadenceRow
                }
            case .accessoryInline:
                Text("\(snapshot.weekStreak) weeks in a row")
            default:
                system
            }
        }
        .widgetURL(URL(string: "vivobody://insights/consistency"))
        .containerBackground(.black, for: .widget)
    }

    @ViewBuilder
    private var system: some View {
        switch family {
        case .systemSmall:
            smallSystem.padding()
        case .systemMedium:
            mediumSystem.padding()
        case .systemLarge:
            largeSystem.padding()
        default:
            smallSystem.padding()
        }
    }

    private var smallSystem: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Streak")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Text("\(snapshot.weekStreak)")
                    .font(Typography.metricHero)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                Text("weeks")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.secondary)
            }
            Spacer(minLength: 0)
            cadenceRow
        }
    }

    private var mediumSystem: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text("Consistency")
                .font(Typography.title)
                .foregroundStyle(Ink.primary)
            ConsistencyHeatmapGrid(weeks: Array(snapshot.weeks.suffix(8)), cellSpacing: 3)
                .accessibilityLabel("Training heatmap")
            Spacer(minLength: 0)
            statLine
        }
    }

    private var largeSystem: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Consistency")
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                Spacer()
                Text("last 6 months")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
            }
            statLine
            ConsistencyHeatmapGrid(weeks: snapshot.weeks, cellSpacing: 3)
                .accessibilityLabel("Training heatmap, \(snapshot.daysTrained) days trained in the last six months")
            WeeklyVolumeSparkline(values: snapshot.weeklyVolume)
            HeatmapLegend()
        }
    }

    private var cadenceRow: some View {
        HStack(spacing: 4) {
            ForEach((snapshot.weeks.last ?? []).indices, id: \.self) { index in
                let day = (snapshot.weeks.last ?? [])[index]
                Circle()
                    .fill(day.level > 0 ? Tint.primary : Ink.primary.opacity(0.10))
                    .frame(width: 10, height: 10)
                    .overlay {
                        if day.isToday {
                            Circle().stroke(Ink.secondary, lineWidth: 1)
                        }
                    }
                    .widgetAccentable()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week: \(trainedDayCount) of \(totalDayCount) days trained")
    }

    private var trainedDayCount: Int {
        (snapshot.weeks.last ?? []).filter { $0.level > 0 }.count
    }

    private var totalDayCount: Int {
        (snapshot.weeks.last ?? []).count
    }

    private var statLine: some View {
        WidgetStatStrip(
            stats: [
                WidgetStat(value: snapshot.sessionsPerWeek.widgetOneDecimal, label: "Per week", accent: snapshot.sessionsPerWeek >= 2),
                WidgetStat(value: "\(snapshot.weekStreak)", label: "Week streak"),
                WidgetStat(value: snapshot.averageRIR?.widgetOneDecimal ?? "-", label: "Avg RIR"),
            ],
            compact: family == .systemMedium
        )
    }
}

// MARK: - Signature

struct SignatureWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetShared.signatureKind,
            provider: SnapshotProvider(
                key: WidgetShared.signatureSnapshotKey,
                fallback: SignatureSnapshot.placeholder,
                refreshInterval: 24 * 60 * 60
            )
        ) { entry in
            SignatureWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Your Signature")
        .description("The shape of your training in one mark.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct SignatureWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: SignatureSnapshot

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                SignatureEmblem(snapshot: snapshot, showsLabels: false)
                    .padding(4)
            case .accessoryRectangular:
                HStack(spacing: Space.sm) {
                    SignatureEmblem(snapshot: snapshot, showsLabels: false)
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.dominantGroup.map { "\($0)-led" } ?? "Balanced")
                            .font(Typography.headline)
                        Text(String(format: "%.1fx a week", snapshot.cadence))
                            .font(Typography.metricUnit)
                            .foregroundStyle(Ink.secondary)
                    }
                }
            case .accessoryInline:
                Text(snapshot.verdictLine)
            default:
                system
            }
        }
        .widgetURL(URL(string: "vivobody://insights"))
        .containerBackground(.black, for: .widget)
    }

    @ViewBuilder
    private var system: some View {
        switch family {
        case .systemSmall:
            smallSystem.padding()
        case .systemMedium:
            mediumSystem.padding()
        case .systemLarge:
            largeSystem.padding()
        default:
            smallSystem.padding()
        }
    }

    private var smallSystem: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("Your signature")
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
            if snapshot.hasSignature {
                SignatureEmblem(snapshot: snapshot, showsLabels: false)
                    .frame(maxWidth: .infinity, maxHeight: 92)
                Text(snapshot.verdictLine)
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                Spacer(minLength: 0)
                Text(snapshot.verdictLine)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(3)
            }
        }
    }

    private var mediumSystem: some View {
        HStack(alignment: .center, spacing: Space.lg) {
            SignatureEmblem(snapshot: snapshot, showsLabels: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Your signature")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
                Text(snapshot.verdictLine)
                    .font(Typography.body)
                    .foregroundStyle(snapshot.hasSignature ? Ink.primary : Ink.secondary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
                WidgetStatStrip(stats: signatureStats, compact: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var largeSystem: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your signature")
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                Spacer()
                Text("the shape of your training")
                    .font(Typography.sectionLabel)
                    .foregroundStyle(Ink.tertiary)
            }

            if snapshot.hasSignature {
                SignatureEmblem(snapshot: snapshot, showsLabels: true)
                    .frame(maxWidth: .infinity, minHeight: 170, maxHeight: 190)
                WidgetStatStrip(stats: signatureStats)
                Text(snapshot.verdictLine)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(2)
                Text("Each petal is a muscle group - its reach is how developed it is, its width how much of your volume it takes.")
                    .font(Typography.caption)
                    .foregroundStyle(Ink.tertiary)
                    .lineLimit(3)
            } else {
                Spacer(minLength: 0)
                Text(snapshot.verdictLine)
                    .font(Typography.body)
                    .foregroundStyle(Ink.secondary)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
        }
    }

    private var signatureStats: [WidgetStat] {
        [
            WidgetStat(value: snapshot.cadence.widgetOneDecimal, label: "Per week", accent: snapshot.cadence >= 2),
            WidgetStat(value: "\(snapshot.weekStreak)", label: "Streak"),
            WidgetStat(value: "\(Int((snapshot.balance * 100).rounded()))", unit: "%", label: "Balance"),
        ]
    }
}

struct SignatureEmblem: View {
    let snapshot: SignatureSnapshot
    var showsLabels: Bool
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        Canvas { context, size in
            guard !snapshot.petals.isEmpty else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let count = snapshot.petals.count
            let maxShare = snapshot.petals.map(\.volumeShare).max() ?? 0
            let ring = Path(ellipseIn: CGRect(
                x: center.x - radius * 0.78,
                y: center.y - radius * 0.78,
                width: radius * 1.56,
                height: radius * 1.56
            ))
            context.stroke(ring, with: .color(Surface.cardTint), lineWidth: 1)

            for (index, petal) in snapshot.petals.enumerated() {
                let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
                let dominant = petal.group == snapshot.dominantGroup
                var spoke = Path()
                spoke.move(to: CGPoint(x: center.x + cos(angle) * radius * 0.08, y: center.y + sin(angle) * radius * 0.08))
                spoke.addLine(to: CGPoint(x: center.x + cos(angle) * radius * 0.82, y: center.y + sin(angle) * radius * 0.82))
                context.stroke(spoke, with: .color(spokeColor(isDominant: dominant)), lineWidth: 1)
            }

            for (index, petal) in snapshot.petals.enumerated() {
                let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
                let length = radius * (0.20 + 0.62 * petal.development)
                let share = maxShare > 0 ? petal.volumeShare / maxShare : 0
                let halfWidth = radius * (0.05 + 0.28 * share)
                let dominant = petal.group == snapshot.dominantGroup
                let opacity = min(1, (0.28 + 0.55 * petal.development) * (0.55 + 0.45 * snapshot.intensity) + (dominant ? 0.18 : 0))

                var leaf = Path()
                let tip = CGPoint(x: length, y: 0)
                leaf.move(to: .zero)
                leaf.addQuadCurve(to: tip, control: CGPoint(x: length * 0.5, y: halfWidth))
                leaf.addQuadCurve(to: .zero, control: CGPoint(x: length * 0.5, y: -halfWidth))

                var transform = CGAffineTransform(translationX: center.x, y: center.y)
                transform = transform.rotated(by: angle)
                context.fill(leaf.applying(transform), with: .color(petalColor(opacity: opacity)))

                if showsLabels {
                    let p = CGPoint(x: center.x + cos(angle) * radius * 0.88, y: center.y + sin(angle) * radius * 0.88)
                    let label = Text(petal.group.prefix(3).uppercased())
                        .font(Typography.micro)
                        .foregroundStyle(dominant ? Ink.primary : Ink.tertiary)
                    context.draw(label, at: p, anchor: .center)
                }
            }

            let core = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: core), with: .color(renderingMode == .vibrant ? .white : Tint.primary))
        }
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.verdictLine.isEmpty ? "Training signature" : snapshot.verdictLine)
    }

    private func petalColor(opacity: Double) -> Color {
        renderingMode == .vibrant ? .white.opacity(opacity) : Tint.primary.opacity(opacity)
    }

    private func spokeColor(isDominant: Bool) -> Color {
        if renderingMode == .vibrant {
            return .white.opacity(isDominant ? 0.45 : 0.10)
        }
        return isDominant ? Tint.primary.opacity(0.45) : Ink.primary.opacity(0.05)
    }
}

// MARK: - Start Workout Control (Action Button)

/// A Control Center / Lock Screen / Action Button control that starts
/// today's workout. Reuses the existing StartTodaysWorkoutIntent
/// (shared WidgetIntents) which sets the App Group handoff flag and
/// opens the app. On iPhone 16+ the user assigns this in
/// Settings > Action Button > Control.
struct StartWorkoutControl: ControlWidget {
    static let kind = WidgetShared.startWorkoutControlKind

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartTodaysWorkoutIntent()) {
                Label("Start Workout", systemImage: "figure.run")
            }
        }
        .displayName("Start Workout")
        .description("Start today's vivobody workout.")
    }
}

// MARK: - Active Workout Live Activity

struct ActiveWorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            ActiveWorkoutActivityView(state: context.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(Tint.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.isResting {
                        restTimerBlock(context.state)
                    } else {
                        setSpecBlock(context.state)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(context.state.exerciseName)
                            .font(Typography.headline)
                            .lineLimit(1)
                        Text("Set \(context.state.setNumber)/\(context.state.plannedSets)")
                            .font(Typography.metricUnit)
                            .foregroundStyle(Ink.secondary)
                        if !context.state.isResting {
                            Button(intent: CompleteActiveSetIntent()) {
                                Text("Complete")
                                    .font(Typography.caption)
                            }
                            .buttonStyle(.glass)
                            .tint(Tint.primary)
                        }
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle().fill(Tint.primary).frame(width: 6, height: 6)
                    if !context.state.isResting {
                        Text("\(context.state.setNumber)/\(context.state.plannedSets)")
                            .font(Typography.metricUnit)
                            .monospacedDigit()
                    }
                }
            } compactTrailing: {
                restOrSetValue(context.state)
            } minimal: {
                Circle().fill(Tint.primary).frame(width: 7, height: 7)
            }
        }
    }

    @ViewBuilder
    private func restOrSetValue(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        if state.isResting, let restEndsAt = state.restEndsAt {
            Text(timerInterval: Date()...restEndsAt, countsDown: true)
                .font(Typography.metricUnit)
                .monospacedDigit()
        } else {
            Text("\(state.setNumber)/\(state.plannedSets)")
                .font(Typography.metricUnit)
                .monospacedDigit()
        }
    }

    private func restTimerBlock(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let restEndsAt = state.restEndsAt {
                Text(timerInterval: Date()...restEndsAt, countsDown: true)
                    .font(Typography.metricLg)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                ProgressView(timerInterval: Date()...restEndsAt, countsDown: true)
                    .tint(Tint.inProgress)
                    .frame(width: 92)
            }
        }
    }

    private func setSpecBlock(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(state.setSpec)
                .font(Typography.statValue)
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("Set \(state.setNumber) of \(state.plannedSets)")
                .font(Typography.metricUnit)
                .foregroundStyle(Ink.secondary)
        }
    }
}

struct ActiveWorkoutActivityView: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(state.exerciseName)
                .font(Typography.sectionLabel)
                .foregroundStyle(Ink.tertiary)
                .lineLimit(1)

            if state.isResting, let restEndsAt = state.restEndsAt {
                Text(timerInterval: Date()...restEndsAt, countsDown: true)
                    .font(Typography.metricLg)
                    .foregroundStyle(Ink.primary)
                    .monospacedDigit()
                ProgressView(timerInterval: Date()...restEndsAt, countsDown: true)
                    .tint(Tint.inProgress)
                    .frame(height: 3)
                Text("Set \(state.setNumber) of \(state.plannedSets)")
                    .font(Typography.metricUnit)
                    .foregroundStyle(Ink.secondary)
            } else {
                Text(state.exerciseName)
                    .font(Typography.title)
                    .foregroundStyle(Ink.primary)
                    .lineLimit(1)
                Text("Set \(state.setNumber) of \(state.plannedSets)")
                    .font(Typography.metricInline)
                    .foregroundStyle(Ink.secondary)
                HStack(alignment: .center, spacing: Space.md) {
                    Text(state.setSpec)
                        .font(Typography.statValue)
                        .foregroundStyle(Ink.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Spacer(minLength: Space.sm)
                    Button(intent: CompleteActiveSetIntent()) {
                        Text("Complete")
                            .font(Typography.headline)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Tint.primary)
                }
            }
        }
        .padding()
    }
}
