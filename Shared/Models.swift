import Foundation
import FamilyControls

/// A named set of apps to block, such as Work or Sleep. (Decision 2)
struct FocusMode: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var selection = FamilyActivitySelection()
    /// Decision 6: a mode can also start on a schedule. A card is always needed to unlock.
    var scheduleEnabled = false
    var startHour = 23
    var startMinute = 0

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

    var startTimeText: String {
        var components = DateComponents()
        components.hour = startHour
        components.minute = startMinute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// "8 apps · 11:00 PM"
    var detail: String {
        scheduleEnabled ? "\(selectionSummary) · \(startTimeText)" : selectionSummary
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
}

/// One finished lock, kept for Focus Card stats.
struct FocusSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var modeName: String
    var start: Date
    var end: Date
    /// True when it ended with an emergency unlock instead of a card.
    var emergency: Bool

    var duration: TimeInterval { end.timeIntervalSince(start) }
}
