import Charts
import SwiftUI

/// Home's stats card content (canvas screen 1).
struct SummaryView: View {
    let stats: PeriodStats

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Daily average, this week")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(Format.duration(stats.average))
                    .font(.system(size: 30, weight: .semibold))
                Text(subtitle)
                    .font(.footnote)
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(stats.bars.suffix(7)) { bar in
                    Capsule()
                        .fill(bar.isLatest ? Color.primary : Color.secondary.opacity(0.45))
                        .frame(width: 8, height: max(6, 56 * height(bar)))
                }
            }
            .frame(height: 56, alignment: .bottom)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var subtitle: String {
        let pickups = "\(Int(stats.pickupsPerDay.rounded())) pickups a day"
        guard let change = stats.changeFraction else { return pickups }
        let percent = Int((abs(change) * 100).rounded())
        return "\(percent)% \(change < 0 ? "below" : "above") last week · \(pickups)"
    }

    private func height(_ bar: Bar) -> CGFloat {
        let peak = stats.bars.suffix(7).map(\.seconds).max() ?? 0
        return peak > 0 ? CGFloat(bar.seconds / peak) : 0
    }
}

/// The full Stats screen content (canvas screen 6).
struct StatsReportView: View {
    let stats: PeriodStats
    /// Drives the draw-in animation: the chart grows from zero when it appears.
    @State private var drawn = false

    var body: some View {
        VStack(spacing: 18) {
            screenTimeCard
            card {
                row("Pickups a day", value: "\(Int(stats.pickupsPerDay.rounded()))", note: pickupChange)
            }
            if stats.period != .day {
                card(title: "Week heatmap") {
                    heatmap
                        .padding(.vertical, 12)
                }
            }
            if !stats.topApps.isEmpty {
                card(title: stats.period == .day ? "Top apps today" : "Top apps, daily average") {
                    ForEach(Array(stats.topApps.enumerated()), id: \.element.id) { index, app in
                        if index > 0 { Divider() }
                        row(app.name, value: Format.duration(app.average), note: Format.change(app.change))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var screenTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(stats.period == .day ? "Screen time today" : "Screen time, daily average")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(Format.duration(stats.average))
                        .font(.system(size: 30, weight: .semibold))
                }
                Spacer()
                if let change = stats.changeFraction {
                    Text("\(change < 0 ? "↓" : "↑") \(Int((abs(change) * 100).rounded()))% vs \(stats.period.comparisonText)")
                        .font(.subheadline)
                }
            }
            Chart {
                if stats.period.hourly {
                    ForEach(stats.bars) { bar in
                        BarMark(
                            x: .value("Time", bar.date, unit: .hour),
                            y: .value("Minutes", drawn ? bar.seconds / 60 : 0)
                        )
                        .foregroundStyle(bar.isLatest ? Color.primary : Color.secondary.opacity(0.45))
                        .cornerRadius(4)
                    }
                } else {
                    ForEach(stats.bars) { bar in
                        AreaMark(
                            x: .value("Day", bar.date, unit: .day),
                            y: .value("Minutes", drawn ? bar.seconds / 60 : 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(
                            colors: [Color.primary.opacity(0.18), Color.primary.opacity(0)],
                            startPoint: .top, endPoint: .bottom))
                        LineMark(
                            x: .value("Day", bar.date, unit: .day),
                            y: .value("Minutes", drawn ? bar.seconds / 60 : 0)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .foregroundStyle(Color.primary)
                    }
                }
                RuleMark(y: .value("Average", stats.baseline / 60))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(Color.secondary)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let minutes = value.as(Double.self) { Text(Format.duration(minutes * 60)) }
                    }
                }
            }
            .animation(.spring(duration: 0.8), value: drawn)
            .onAppear { drawn = true }
            .frame(height: 160)
            Text("Dashed line: \(stats.period.averageText), \(Format.duration(stats.baseline))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    /// One cell per day, darker for more screen time (chart 4).
    private var heatmap: some View {
        let days = Array(stats.bars.suffix(7))
        let peak = days.map(\.seconds).max() ?? 0
        return HStack(spacing: 6) {
            ForEach(days) { bar in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(peak > 0 ? 0.1 + 0.9 * bar.seconds / peak : 0.1))
                        .frame(height: 34)
                    Text(bar.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(bar.date.formatted(.dateTime.weekday(.wide))), \(Format.duration(bar.seconds))")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var pickupChange: String? {
        guard stats.previousPickupsPerDay > 0 else { return nil }
        let change = Int((stats.pickupsPerDay - stats.previousPickupsPerDay).rounded())
        return "\(change < 0 ? "↓" : "↑") \(abs(change))"
    }

    private func card<Content: View>(title: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
            }
            content()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private func row(_ name: String, value: String, note: String?) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(value).fontWeight(.semibold)
            if let note {
                Text(note).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }
}
