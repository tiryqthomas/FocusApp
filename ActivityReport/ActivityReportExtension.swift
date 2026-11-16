import DeviceActivity
import SwiftUI

/// Draws Screen Time stats inside the app (Decisions 12 to 14).
/// Apple keeps this data inside the extension: the app can show the view
/// but can't read the numbers.
@main
struct ActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        SummaryReport { SummaryView(stats: $0) }
        StatsReport(context: .statsDay, period: .day) { StatsReportView(stats: $0) }
        StatsReport(context: .statsWeek, period: .week) { StatsReportView(stats: $0) }
        StatsReport(context: .statsMonth, period: .month) { StatsReportView(stats: $0) }
    }
}

extension DeviceActivityReport.Context {
    static let summary = Self("summary")
    static let statsDay = Self("statsDay")
    static let statsWeek = Self("statsWeek")
    static let statsMonth = Self("statsMonth")
}

/// Home's stats card: this week's daily average.
struct SummaryReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .summary
    let content: (PeriodStats) -> SummaryView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> PeriodStats {
        await StatsBuilder.build(from: data, period: .week)
    }
}

/// The full Stats screen for one range.
struct StatsReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context
    let period: Period
    let content: (PeriodStats) -> StatsReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> PeriodStats {
        await StatsBuilder.build(from: data, period: period)
    }
}
