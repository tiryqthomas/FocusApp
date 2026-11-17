import Foundation
import FamilyControls

/// The apps to block while locked. The simplified app has one mode, Work.
struct FocusMode: Codable, Equatable {
    var name = "Work"
    var selection = FamilyActivitySelection()

    var isEmpty: Bool {
        selection.applicationTokens.isEmpty
            && selection.categoryTokens.isEmpty
            && selection.webDomainTokens.isEmpty
    }

    /// "8 apps, 2 categories"
    var selectionSummary: String {
        let apps = selection.applicationTokens.count
        let categories = selection.categoryTokens.count
        let sites = selection.webDomainTokens.count
        var parts: [String] = []
        if apps > 0 { parts.append(apps == 1 ? "1 app" : "\(apps) apps") }
        if categories > 0 { parts.append(categories == 1 ? "1 category" : "\(categories) categories") }
        if sites > 0 { parts.append(sites == 1 ? "1 website" : "\(sites) websites") }
        return parts.isEmpty ? "No apps chosen" : parts.joined(separator: ", ")
    }
}

/// The NFC card or sticker that locks and unlocks.
struct PairedCard: Codable, Equatable {
    /// Hex of the card's first NDEF record (what is written on it, not the chip ID).
    var tagID: String
    var added = Date()
}

/// Present while locked.
struct LockState: Codable, Equatable {
    var modeName: String
    var since: Date
}

/// Emergency unlocks: a weekly allowance that refills every Monday.
struct EmergencyAllowance: Codable, Equatable {
    var perWeek = 5
    var used = 0
    /// Start of the week `used` counts from.
    var weekStart = EmergencyAllowance.mondayOfThisWeek()

    var remaining: Int { max(0, perWeek - used) }

    /// Clears `used` when a new week has started.
    mutating func refillIfNewWeek(now: Date = .now) {
        let monday = Self.mondayOfThisWeek(now)
        if monday > weekStart {
            weekStart = monday
            used = 0
        }
    }

    static func mondayOfThisWeek(_ date: Date = .now) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}

/// How unlocking ended a session, kept for stats.
enum UnlockMethod: String, Codable {
    case card, emergency, recovery
}

/// Time spent locked, per day ("2026-11-16" -> seconds), plus simple counters.
struct FocusLog: Codable, Equatable {
    var secondsByDay: [String: Double] = [:]
    var longestSession: Double = 0
    var cardUnlocks = 0

    static func key(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Adds a finished session, splitting it across midnight if needed.
    mutating func add(from start: Date, to end: Date) {
        guard end > start else { return }
        longestSession = max(longestSession, end.timeIntervalSince(start))
        let calendar = Calendar.current
        var cursor = start
        while cursor < end {
            let nextMidnight = calendar.startOfDay(for: cursor).addingTimeInterval(86_400)
            let sliceEnd = min(end, nextMidnight)
            secondsByDay[Self.key(cursor), default: 0] += sliceEnd.timeIntervalSince(cursor)
            cursor = sliceEnd
        }
    }

    func seconds(on date: Date) -> Double { secondsByDay[Self.key(date)] ?? 0 }

    /// Days in a row, ending today or yesterday, with any locked time.
    func streak(now: Date = .now) -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: now)
        if seconds(on: day) == 0 { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var count = 0
        while seconds(on: day) > 0 {
            count += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }
}

/// Light, dark, or follow the system.
enum Appearance: String, CaseIterable, Codable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
