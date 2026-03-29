import Foundation

// MARK: - Session Model

struct HistorySession: Identifiable {
    let id: String
    let dayNumber: String
    let dayName: String
    let date: String
    let name: String
    let muscles: String
    let duration: String
    let volume: String
    let sets: String
    let prCount: Int
    let timeAgo: String
}

// MARK: - Sample Data

extension WorkoutsHistoryView {
    static let thisWeekSessions: [HistorySession] = [
        HistorySession(
            id: "tw1", dayNumber: "03", dayName: "WED", date: "18",
            name: "Upper Body Push",
            muscles: "6 exercises \u{00B7} chest, delts, triceps",
            duration: "52:10", volume: "14,820 lb", sets: "22 sets",
            prCount: 2, timeAgo: "2h ago"
        ),
        HistorySession(
            id: "tw2", dayNumber: "02", dayName: "TUE", date: "17",
            name: "Lower Body",
            muscles: "6 exercises \u{00B7} quads, hams, glutes",
            duration: "52:10", volume: "8,420 lb", sets: "20 sets",
            prCount: 0, timeAgo: "Yesterday"
        ),
        HistorySession(
            id: "tw3", dayNumber: "01", dayName: "MON", date: "16",
            name: "Upper Body Pull",
            muscles: "5 exercises \u{00B7} back, biceps, rear delts",
            duration: "47:32", volume: "11,200 lb", sets: "18 sets",
            prCount: 1, timeAgo: "2d ago"
        )
    ]

    static let lastWeekSessions: [HistorySession] = [
        HistorySession(
            id: "lw1", dayNumber: "07", dayName: "SUN", date: "15",
            name: "Upper Pull B",
            muscles: "5 exercises \u{00B7} back, biceps",
            duration: "50:18", volume: "10,840 lb", sets: "18 sets",
            prCount: 0, timeAgo: "Mar 15"
        ),
        HistorySession(
            id: "lw2", dayNumber: "05", dayName: "FRI", date: "13",
            name: "Full Body",
            muscles: "7 exercises \u{00B7} compound focus",
            duration: "55:42", volume: "16,200 lb", sets: "24 sets",
            prCount: 3, timeAgo: "Mar 13"
        ),
        HistorySession(
            id: "lw3", dayNumber: "03", dayName: "WED", date: "11",
            name: "Upper Body Push",
            muscles: "6 exercises \u{00B7} chest, delts, triceps",
            duration: "55:02", volume: "13,580 lb", sets: "22 sets",
            prCount: 1, timeAgo: "Mar 11"
        ),
        HistorySession(
            id: "lw4", dayNumber: "02", dayName: "TUE", date: "10",
            name: "Lower Body",
            muscles: "6 exercises \u{00B7} quads, hams, glutes",
            duration: "48:30", volume: "7,920 lb", sets: "20 sets",
            prCount: 0, timeAgo: "Mar 10"
        ),
        HistorySession(
            id: "lw5", dayNumber: "01", dayName: "MON", date: "09",
            name: "Upper Body Pull",
            muscles: "5 exercises \u{00B7} back, biceps, rear delts",
            duration: "46:12", volume: "10,600 lb", sets: "17 sets",
            prCount: 0, timeAgo: "Mar 09"
        )
    ]

    static let olderSessions: [HistorySession] = [
        HistorySession(
            id: "o1", dayNumber: "07", dayName: "SAT", date: "08",
            name: "Full Body",
            muscles: "7 exercises \u{00B7} compound focus",
            duration: "58:10", volume: "15,400 lb", sets: "24 sets",
            prCount: 1, timeAgo: "Mar 08"
        ),
        HistorySession(
            id: "o2", dayNumber: "05", dayName: "THU", date: "06",
            name: "Upper Body Push",
            muscles: "6 exercises \u{00B7} chest, delts, triceps",
            duration: "51:20", volume: "12,980 lb", sets: "22 sets",
            prCount: 0, timeAgo: "Mar 06"
        )
    ]
}
