import Foundation
import FamilyControls

/// The one Night routine: which apps to block, bedtime and wake time.
struct FocusMode: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var selection = FamilyActivitySelection()
    /// The lock starts by itself at bedtime. A card (after wake time) ends it.
    var scheduleEnabled = true
    var startHour = 23
    var startMinute = 0
    var wakeHour = 7
    var wakeMinute = 0
    /// Hours after wake time that stay locked too. Nil means the default of 1.
    var protectHours: Int? = nil
    var morningHours: Int { protectHours ?? 1 }
    /// SleepKey rings its own wake alarm at wake time. Nil means on.
    var wakeAlarm: Bool? = nil
    var wakeAlarmOn: Bool { wakeAlarm ?? true }

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

    private static func text(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    var startTimeText: String { Self.text(hour: startHour, minute: startMinute) }
    var wakeTimeText: String { Self.text(hour: wakeHour, minute: wakeMinute) }

    /// The next time the clock reads bedtime, after `date`.
    func nextBedtime(after date: Date = .now) -> Date {
        Calendar.current.nextDate(
            after: date,
            matching: DateComponents(hour: startHour, minute: startMinute),
            matchingPolicy: .nextTime
        ) ?? date
    }

    /// The next time the clock reads wake time, after `date`.
    func nextWake(after date: Date = .now) -> Date {
        Calendar.current.nextDate(
            after: date,
            matching: DateComponents(hour: wakeHour, minute: wakeMinute),
            matchingPolicy: .nextTime
        ) ?? date
    }
}

/// An NFC card or sticker that can lock and unlock any mode. (Decisions 4 and 8)
struct PairedCard: Identifiable, Codable, Equatable {
    var id = UUID()
    /// The tag's hardware identifier, as hex.
    var tagID: String
    var name: String
    var added = Date()
}

/// The mode that is locked right now.
struct LockState: Codable, Equatable {
    var modeID: UUID
    var modeName: String
    var since: Date
    /// True for the bedtime lock, false for a daytime "Lock now".
    var night: Bool? = nil
    /// Night locks only: before this time the card does nothing.
    var wakeAt: Date? = nil
}

/// One finished lock, kept for SleepKey stats.
struct FocusSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var modeName: String
    var start: Date
    var end: Date
    /// True when it ended with an emergency unlock instead of a card.
    var emergency: Bool
    var night: Bool? = nil

    var duration: TimeInterval { end.timeIntervalSince(start) }
}
