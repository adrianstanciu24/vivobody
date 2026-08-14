//
//  vivobodyWidgetsBundle.swift
//  vivobodyWidgets
//
//  WidgetKit entry point for vivobody's glanceable surfaces. The
//  individual widget implementations live in their own files:
//    • UpNextWidget.swift (small only)
//    • SignatureWidget.swift (small only)
//    • ConsistencyWidget.swift (medium only)
//    • StrengthWidget.swift (large only)
//    • StartWorkoutControl.swift
//    • ActiveWorkoutLiveActivity.swift
//  Shared view primitives are in WidgetChrome.swift.
//

import ActivityKit
import AppIntents
import SwiftUI
import VivoKit
import WidgetKit

@main
struct vivobodyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        UpNextWidget()
        SignatureWidget()
        ConsistencyWidget()
        StrengthWidget()
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
    /// Shown only in the widget gallery (placeholder context).
    let galleryPlaceholder: Snapshot
    /// Shown on the real timeline when no snapshot has been written yet.
    let empty: Snapshot
    let refreshInterval: TimeInterval

    func placeholder(in _: Context) -> SnapshotEntry<Snapshot> {
        SnapshotEntry(date: Date(), snapshot: galleryPlaceholder)
    }

    func getSnapshot(in _: Context, completion: @escaping (SnapshotEntry<Snapshot>) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: readSnapshot()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<SnapshotEntry<Snapshot>>) -> Void) {
        let now = Date()
        let entry = SnapshotEntry(date: now, snapshot: readSnapshot())
        let next = now.addingTimeInterval(refreshInterval)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func readSnapshot() -> Snapshot {
        let data = UserDefaults(suiteName: WidgetShared.appGroup)?
            .data(forKey: key)
        return WidgetSnapshotCodec.decode(
            Snapshot.self,
            from: data,
            fallback: empty
        )
    }
}
