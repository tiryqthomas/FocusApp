import SwiftUI

/// Day, Week or Month, for the chart and the Stats screen.
enum StatsRange: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }
    var title: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        }
    }
    var short: String { String(title.prefix(1)) }
}

/// Placeholder screen time figures. Real numbers only exist inside a
/// DeviceActivityReport extension (parked for now), so the charts use these.
enum SampleStats {
    enum Category: Int, CaseIterable, Identifiable {
        case social, entertainment, productivity, other
        var id: Int { rawValue }
        var name: String {
            switch self {
            case .social: "Social"
            case .entertainment: "Entertainment"
            case .productivity: "Productivity"
            case .other: "Other"
            }
        }
        var color: Color {
            switch self {
            case .social: .blue
            case .entertainment: Color(.systemCyan)
            case .productivity: .orange
            case .other: Color(.systemGray3)
            }
        }
        /// Typical minutes per day, before variation.
        var base: Double {
            switch self {
            case .social: 60
            case .entertainment: 40
            case .productivity: 35
            case .other: 25
            }
        }
    }

    struct Bar: Identifiable {
        let index: Int
        let label: String
        let category: Category
        let minutes: Double
        var id: String { "\(index)-\(category.rawValue)" }
    }

    struct App: Identifiable {
        let name: String
        let category: Category
        let minutes: Double
        var id: String { name }
    }

    static let apps: [App] = [
        App(name: "Instagram", category: .social, minutes: 52),
        App(name: "YouTube", category: .entertainment, minutes: 41),
        App(name: "Safari", category: .other, minutes: 28),
        App(name: "TikTok", category: .social, minutes: 24),
        App(name: "Notion", category: .productivity, minutes: 22),
        App(name: "Netflix", category: .entertainment, minutes: 18),
        App(name: "Messages", category: .social, minutes: 15),
        App(name: "Mail", category: .productivity, minutes: 9),
    ]

    /// Fixed pseudo-random numbers, so the charts look the same on every launch.
    private static func noise(_ i: Int, _ c: Int, _ salt: Int) -> Double {
        var x = UInt64(truncatingIfNeeded: (i + 1) &* 7919 &+ (c + 1) &* 104_729 &+ salt &* 1_299_709)
        x ^= x >> 13; x &*= 0x5bd1e995; x ^= x >> 15
        return Double(x % 1000) / 1000
    }

    static func labels(_ range: StatsRange) -> [String] {
        switch range {
        case .day: (0..<24).map { "\($0)" }
        case .week: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        case .month: (1...30).map { "\($0)" }
        }
    }

    /// Axis labels to show (a subset for Day and Month).
    static func axisLabels(_ range: StatsRange) -> [String] {
        switch range {
        case .day: ["0", "6", "12", "18"]
        case .week: labels(.week)
        case .month: ["1", "8", "15", "22", "29"]
        }
    }

    static func axisText(_ label: String, _ range: StatsRange) -> String {
        switch range {
        case .day:
            let h = Int(label) ?? 0
            return h == 0 ? "12a" : h == 12 ? "12p" : h < 12 ? "\(h)a" : "\(h - 12)p"
        case .week: return String(label.prefix(1))
        case .month: return label
        }
    }

    static func bars(_ range: StatsRange) -> [Bar] {
        let names = labels(range)
        var result: [Bar] = []
        for (i, label) in names.enumerated() {
            for category in Category.allCases {
                var minutes = category.base * (0.5 + noise(i, category.rawValue, range == .day ? 1 : range == .week ? 2 : 3))
                if range == .day {
                    minutes *= 0.06
                    if i < 7 || i > 22 { minutes *= 0.1 }
                }
                result.append(Bar(index: i, label: label, category: category, minutes: minutes.rounded()))
            }
        }
        return result
    }

    /// Totals per bar, for one category or all of them.
    static func totals(_ range: StatsRange, category: Category? = nil) -> [(label: String, minutes: Double)] {
        let all = bars(range).filter { category == nil || $0.category == category }
        return labels(range).map { label in
            (label, all.filter { $0.label == label }.reduce(0) { $0 + $1.minutes })
        }
    }

    /// Headline figure: the day's total for Day, otherwise the daily average.
    static func headline(_ range: StatsRange, category: Category? = nil) -> Double {
        let t = totals(range, category: category).map(\.minutes)
        let sum = t.reduce(0, +)
        return range == .day ? sum : sum / Double(max(t.count, 1))
    }

    static func change(_ range: StatsRange) -> String {
        switch range {
        case .day: "↓ 24m from yesterday"
        case .week: "↓ 18% from last week"
        case .month: "↓ 9% from last month"
        }
    }

    /// 7 days by 8 three-hour blocks, 0 to 1.
    static let heatmap: [[Double]] = (0..<7).map { d in
        (0..<8).map { b in
            let base = [0.05, 0.02, 0.35, 0.55, 0.5, 0.6, 0.85, 0.55][b]
            return min(1, base * (d > 4 ? 1.2 : 1) * (0.6 + noise(d, b, 3) * 0.7))
        }
    }

    /// Sample pickups today, until the Screen Time report is connected.
    static let pickupsToday = 41

    /// Ring targets on Home. Placeholders until they're editable.
    static let focusGoalSeconds: Double = 4 * 3600
    static let screenLimitMinutes: Double = 4 * 60
    static let pickupsLimit: Double = 80

    static func format(minutes: Double) -> String {
        let m = Int(minutes.rounded())
        return "\(m / 60)h \(m % 60)m"
    }
}

/// "2h 14m" from seconds.
func formatDuration(_ seconds: Double) -> String {
    let m = Int(seconds / 60)
    return "\(m / 60)h \(m % 60)m"
}
