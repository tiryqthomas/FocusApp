import DeviceActivity
import Foundation

/// Must match the ranges the app asks for in StatsRange.filter.
enum Period {
    case day, week, month

    /// Days in the current period.
    var days: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 28
        }
    }

    /// Days of data the app fetches. The extra days give the comparison and the average line.
    var fetchedDays: Int {
        switch self {
        case .day: 2
        case .week: 28
        case .month: 56
        }
    }

    var hourly: Bool { self == .day }

    var comparisonText: String {
        switch self {
        case .day: "yesterday"
        case .week: "last week"
        case .month: "the 4 weeks before"
        }
    }

    var averageText: String {
        switch self {
        case .day: "hourly average over 2 days"
        case .week: "4-week daily average"
        case .month: "8-week daily average"
        }
    }
}

struct Bar: Identifiable {
    let date: Date
    var seconds: TimeInterval
    var isLatest = false
    var id: Date { date }
}

struct AppRow: Identifiable {
    let id: String
    let name: String
    /// Per day in the current period.
    let average: TimeInterval
    let change: TimeInterval
}

struct PeriodStats {
    var period: Period = .week
    /// Daily average for week and month. Today's total for day.
    var average: TimeInterval = 0
    var previousAverage: TimeInterval = 0
    /// Per bar, across everything fetched. Drawn as the dashed line.
    var baseline: TimeInterval = 0
    var pickupsPerDay: Double = 0
    var previousPickupsPerDay: Double = 0
    var bars: [Bar] = []
    var topApps: [AppRow] = []

    /// Negative means less screen time than before.
    var changeFraction: Double? {
        previousAverage > 0 ? (average - previousAverage) / previousAverage : nil
    }
}

enum StatsBuilder {
    static func build(from data: DeviceActivityResults<DeviceActivityData>, period: Period) async -> PeriodStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let currentStart = calendar.date(byAdding: .day, value: -(period.days - 1), to: today) ?? today
        let previousStart = calendar.date(byAdding: .day, value: -period.days, to: currentStart) ?? currentStart

        var current: TimeInterval = 0
        var previous: TimeInterval = 0
        var all: TimeInterval = 0
        var currentPickups = 0
        var previousPickups = 0
        var bars: [Date: TimeInterval] = [:]
        var currentApps: [String: (name: String, seconds: TimeInterval)] = [:]
        var previousApps: [String: TimeInterval] = [:]

        for await device in data {
            for await segment in device.activitySegments {
                let start = segment.dateInterval.start
                let duration = segment.totalActivityDuration
                let isCurrent = start >= currentStart
                let isPrevious = !isCurrent && start >= previousStart
                all += duration
                if isCurrent {
                    current += duration
                    bars[start, default: 0] += duration
                } else if isPrevious {
                    previous += duration
                }

                for await category in segment.categories {
                    let loosePickups = category.totalPickupsWithoutApplicationActivity
                    if isCurrent { currentPickups += loosePickups } else if isPrevious { previousPickups += loosePickups }

                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? app.application.bundleIdentifier ?? "App"
                        let key = app.application.bundleIdentifier ?? name
                        if isCurrent {
                            currentPickups += app.numberOfPickups
                            let existing = currentApps[key]?.seconds ?? 0
                            currentApps[key] = (name, existing + app.totalActivityDuration)
                        } else if isPrevious {
                            previousPickups += app.numberOfPickups
                            previousApps[key, default: 0] += app.totalActivityDuration
                        }
                    }
                }
            }
        }

        let days = Double(period.days)
        let barSlots = Double(period.fetchedDays * (period.hourly ? 24 : 1))

        var stats = PeriodStats(period: period)
        stats.average = current / days
        stats.previousAverage = previous / days
        stats.baseline = all / max(barSlots, 1)
        stats.pickupsPerDay = Double(currentPickups) / days
        stats.previousPickupsPerDay = Double(previousPickups) / days

        var sortedBars = bars.map { Bar(date: $0.key, seconds: $0.value) }.sorted { $0.date < $1.date }
        if !sortedBars.isEmpty { sortedBars[sortedBars.count - 1].isLatest = true }
        stats.bars = sortedBars

        stats.topApps = currentApps
            .sorted { $0.value.seconds > $1.value.seconds }
            .prefix(5)
            .map { key, value in
                let average = value.seconds / days
                let previousAverage = (previousApps[key] ?? 0) / days
                return AppRow(id: key, name: value.name, average: average, change: average - previousAverage)
            }
        return stats
    }
}

enum Format {
    /// "3h 12m", "42m"
    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    /// "↓ 12m", "↑ 5m"
    static func change(_ seconds: TimeInterval) -> String {
        let arrow = seconds < 0 ? "↓" : "↑"
        return "\(arrow) \(duration(abs(seconds)))"
    }
}
