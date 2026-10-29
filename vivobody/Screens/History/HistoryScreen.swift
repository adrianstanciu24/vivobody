//
//  HistoryScreen.swift
//  vivobody
//
//  Live list of every archived workout, rendered as a training log
//  with one focal object at the top: the week hero, the screen's
//  only standalone surface. Inside it the hierarchy is volume-led —
//  the week's tonnage as a huge monospaced numeral, then the
//  seven-dot cadence strip (ember dots on trained days, a ring on
//  today), then Avg RIR and workout count as compact secondary
//  stats. The colored trend delta stays pinned to the header.
//
//  Below the hero, sessions are grouped by date bucket (Today /
//  Yesterday / This Week / Last Week / month). Each bucket is a
//  ledger block: a SectionHeader on black, then the bucket's rows
//  inside one shared content card with inset hairlines — Today's
//  card uses the bright surface so the freshest sessions lift.
//
//    • Today — elevated rows: workout title + meta on the left, a
//      larger volume numeral on the right.
//    • Earlier — same row, tighter: date + muscle summary + time on
//      the left, a smaller volume numeral on the right.
//
//  PR sessions carry a small outlined "PR" tag beside the title —
//  the lone accent in the list, so it never dilutes.
//
//  Tapping any row opens a detail view that reuses
//  WorkoutSummaryCard — the same "receipt" the user saw at the end
//  of the workout, now as a permanent record. In compact width the
//  receipt pushes over the list; in regular width it shows beside the
//  list, with the newest session selected until the user picks another.
//

import SwiftData
import SwiftUI

struct HistoryScreen: View {
    @Bindable var appState: AppState

    static let pageSize = 60

    var body: some View {
        HistoryContent(appState: appState)
    }
}

/// The History tab's real body. The live first page remains an `@Query`;
/// older pages append through a keyset cursor so reaching page N never
/// refetches pages 1 ... N-1.
struct HistoryContent: View {
    var appState: AppState

    @Environment(\.modelContext) private var modelContext

    @State private var olderSessions: [WorkoutSession] = []
    @State private var reachedArchiveEnd = false
    @State private var isLoadingPage = false
    @State private var selectedSessionID: UUID?

    @AppStorage(SettingsKey.weightUnit)
    var unitRaw: String = SettingsDefaults.weightUnit

    var unit: WeightUnit {
        WeightUnit(rawValue: unitRaw) ?? .lb
    }

    /// The live newest page. Mid-flight sessions are unarchived and
    /// therefore invisible to this query.
    @Query private var newestSessions: [WorkoutSession]

    /// Sessions from the start of last week onward (with a one-day
    /// pad for boundary-spanning workouts) — everything the weekly
    /// hero needs, without touching the older archive.
    @Query var recentSessions: [WorkoutSession]

    init(appState: AppState) {
        self.appState = appState

        var newest = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.completedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        newest.fetchLimit = HistoryScreen.pageSize
        _newestSessions = Query(newest)

        let calendar = Calendar.current
        let thisWeekStart = calendar
            .dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let cutoff = calendar
            .date(byAdding: .day, value: -8, to: thisWeekStart) ?? thisWeekStart
        _recentSessions = Query(
            filter: #Predicate<WorkoutSession> {
                $0.completedAt != nil && $0.startedAt >= cutoff
            },
            sort: [SortDescriptor(\.completedAt, order: .reverse)]
        )
    }

    var body: some View {
        BrowserColumns(selection: $selectedSessionID) { navigation in
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    content(navigation: navigation)
                }
            }
            .screenBackground()
            .navigationTitle("History")
        } detail: { id, _ in
            sessionDetail(for: id)
        }
        .onChange(of: newestSessions.map(\.id), initial: true) { oldIDs, newIDs in
            if oldIDs != newIDs {
                olderSessions.removeAll(keepingCapacity: true)
                reachedArchiveEnd = false
            }
            reconcileSelection()
        }
    }

    @ViewBuilder
    private func sessionDetail(for id: UUID?) -> some View {
        if let id, let session = sessions.first(where: { $0.id == id }) ?? (try? archivedSession(id)) {
            SessionDetailScreen(session: session)
        } else {
            Color.clear.screenBackground()
        }
    }

    /// Keeps a valid selection, else selects the newest session. A
    /// selection that only left the loaded pages, because a newly archived
    /// workout reset the paging, is still archived and stays selected. A
    /// failed lookup also keeps it: only a confirmed absence is a removal.
    private func reconcileSelection() {
        let loaded = sessions
        selectedSessionID = BrowserSelection.retainOrFirst(
            selectedSessionID,
            isValid: { id in loaded.contains { $0.id == id } || mayStillBeArchived(id) },
            first: loaded.first?.id
        )
    }

    private func mayStillBeArchived(_ id: UUID) -> Bool {
        do {
            return try archivedSession(id) != nil
        } catch {
            return true
        }
    }

    private func archivedSession(_ id: UUID) throws -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == id && $0.completedAt != nil }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    /// Newest live page plus appended older pages, de-duplicated in one
    /// cumulative pass in case a newly archived workout shifts the live page.
    var sessions: [WorkoutSession] {
        var seen = Set<UUID>()
        var result: [WorkoutSession] = []
        result.reserveCapacity(newestSessions.count + olderSessions.count)
        for session in newestSessions + olderSessions where seen.insert(session.id).inserted {
            result.append(session)
        }
        return result
    }

    var hasMoreSessions: Bool {
        !reachedArchiveEnd && !newestSessions.isEmpty
    }

    /// Fetch only the page strictly older than the current indexed,
    /// nonoptional start-time cursor. Completion remains the displayed date.
    @MainActor
    func loadMoreSessions() {
        guard hasMoreSessions, !isLoadingPage, let cursor = sessions.last else {
            return
        }
        let startedAt = cursor.startedAt
        isLoadingPage = true
        defer { isLoadingPage = false }

        var page = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate {
                $0.completedAt != nil
                    && $0.startedAt < startedAt
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        page.fetchLimit = HistoryScreen.pageSize

        do {
            let fetched = try modelContext.fetch(page)
            olderSessions.append(contentsOf: fetched)
            reachedArchiveEnd = fetched.count < HistoryScreen.pageSize
        } catch {
            reachedArchiveEnd = true
        }
    }
}

#Preview {
    HistoryScreen(appState: AppState())
        .preferredColorScheme(.dark)
}
