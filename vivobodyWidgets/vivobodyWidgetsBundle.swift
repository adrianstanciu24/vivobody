//
//  vivobodyWidgetsBundle.swift
//  vivobodyWidgets
//
//  WidgetKit entry point for vivobody's glanceable surfaces. The
//  individual widget implementations live in their own files:
//    • UpNextWidget.swift
//    • ConsistencyWidget.swift
//    • SignatureWidget.swift
//    • StartWorkoutControl.swift
//    • ActiveWorkoutLiveActivity.swift
//  Shared view primitives are in WidgetChrome.swift.
//

import VivoKit
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
