import Charts
import SwiftUI

/// Full stats, opened from the chart on Home.
struct StatsView: View {
    @Environment(AppModel.self) private var model
    @State private var range: StatsRange
    @State private var category: SampleStats.Category?

    init(initialRange: StatsRange) {
        _range = State(initialValue: initialRange)
    }

    private var lineColor: Color { category?.color ?? .blue }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.spacing) {
                // In the page, not the toolbar: a toolbar adds its own glass
                // around the control, which drew a second outline.
                Picker("Range", selection: $range.animation(.snappy)) {
                    ForEach(StatsRange.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 2) {
                    Text(((category.map { $0.name + " · " } ?? "") + (range == .day ? "Today" : "Daily average")).uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Text(SampleStats.format(minutes: SampleStats.headline(range, category: category)))
                        .font(.largeTitle.bold())
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(SampleStats.change(range))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                .padding(.horizontal, 4)

                categoryChips

                card("Trend") { trend }
                card("When you use your phone") { heatmap }
                card("Top apps") { topApps }
                VStack(spacing: Theme.groupSpacing) {
                    SectionLabel("Keycard")
                    focusStats.card(padding: 0)
                }

                Text("Screen time figures are samples until the Screen Time report is connected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, Theme.spacing)
            .padding(.bottom, Theme.spacing * 2)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)

    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.groupSpacing) {
                chip("All", color: .blue, selected: category == nil) { category = nil }
                ForEach(SampleStats.Category.allCases) { c in
                    chip(c.name, color: c.color, selected: category == c) { category = c }
                }
            }
        }
    }

    private func chip(_ title: String, color: Color, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(height: 36)
            .contentShape(Capsule())
            .foregroundStyle(selected ? Color(.systemBackground) : Color.primary)
            .background(selected ? Color.primary : Color(.tertiarySystemFill), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.secondary)
            content()
        }
        .card()
    }

    private var trend: some View {
        let points = SampleStats.totals(range, category: category)
        return Chart {
            ForEach(points, id: \.label) { point in
                AreaMark(x: .value("Time", point.label), y: .value("Minutes", point.minutes))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(lineColor.opacity(0.12))
                LineMark(x: .value("Time", point.label), y: .value("Minutes", point.minutes))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }
            if let last = points.last {
                PointMark(x: .value("Time", last.label), y: .value("Minutes", last.minutes))
                    .foregroundStyle(lineColor)
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: SampleStats.axisLabels(range)) { value in
                AxisValueLabel {
                    if let label = value.as(String.self) {
                        Text(SampleStats.axisText(label, range))
                    }
                }
            }
        }
        .frame(height: 150)
    }

    /// 7 days by 8 three-hour blocks; darker means more use.
    private var heatmap: some View {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        let times = ["12a", "3a", "6a", "9a", "12p", "3p", "6p", "9p"]
        return Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            ForEach(0..<7, id: \.self) { d in
                GridRow {
                    Text(days[d])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 14, alignment: .leading)
                    ForEach(0..<8, id: \.self) { b in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(lineColor.opacity(0.08 + SampleStats.heatmap[d][b] * 0.92))
                            .frame(height: 16)
                    }
                }
            }
            GridRow {
                Color.clear.frame(width: 14, height: 1)
                ForEach(times, id: \.self) { t in
                    Text(t).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var topApps: some View {
        let apps = SampleStats.apps.filter { category == nil || $0.category == category }
        let top = SampleStats.apps.map(\.minutes).max() ?? 1
        return VStack(spacing: 0) {
            if apps.isEmpty {
                Text("No apps in this category").foregroundStyle(.secondary)
            }
            ForEach(Array(apps.prefix(5).enumerated()), id: \.element.id) { index, app in
                if index > 0 { Divider() }
                VStack(spacing: 6) {
                    HStack {
                        Text(app.name)
                        Spacer()
                        Text(SampleStats.format(minutes: app.minutes))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(.tertiarySystemFill))
                            Capsule().fill(app.category.color)
                                .frame(width: proxy.size.width * app.minutes / top)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(.vertical, 9)
            }
        }
    }

    /// Real figures from the app's own lock history.
    private var focusStats: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(spacing: 0) {
                DetailRow(label: "Locked this week") { Text(formatDuration(model.focusedThisWeek(now: context.date))) }
                RowDivider()
                DetailRow(label: "Longest session") { Text(formatDuration(model.focusLog.longestSession)) }
                RowDivider()
                DetailRow(label: "Streak") {
                    let days = model.focusLog.streak(now: context.date)
                    Text(days == 1 ? "1 day" : "\(days) days")
                }
                RowDivider()
                DetailRow(label: "Card unlocks") { Text("\(model.focusLog.cardUnlocks)") }
                RowDivider()
                DetailRow(label: "Emergency unlocks used") { Text("\(model.emergency.used) of \(model.emergency.perWeek)") }
            }
        }
    }
}
