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
