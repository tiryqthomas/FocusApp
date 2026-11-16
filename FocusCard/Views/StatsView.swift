import DeviceActivity
import SwiftUI

extension DeviceActivityReport.Context {
    static let summary = Self("summary")
    static let statsDay = Self("statsDay")
    static let statsWeek = Self("statsWeek")
    static let statsMonth = Self("statsMonth")
}

/// Decision 13: Day, Week and Month, starting on Week.
/// Ranges must match `Period` in the report extension.
enum StatsRange: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 28
        }
    }

    var context: DeviceActivityReport.Context {
        switch self {
        case .day: .statsDay
        case .week: .statsWeek
        case .month: .statsMonth
        }
    }

    var filter: DeviceActivityFilter {
        let calendar = Calendar.current
        let now = Date.now
        let today = calendar.startOfDay(for: now)
        func since(daysBack: Int) -> DateInterval {
            DateInterval(start: calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today, end: now)
        }
        switch self {
        case .day:
            return DeviceActivityFilter(segment: .hourly(during: since(daysBack: 1)), users: .all, devices: .init([.iPhone]))
        case .week:
            return DeviceActivityFilter(segment: .daily(during: since(daysBack: 27)), users: .all, devices: .init([.iPhone]))
        case .month:
            return DeviceActivityFilter(segment: .daily(during: since(daysBack: 55)), users: .all, devices: .init([.iPhone]))
        }
    }
}

/// Canvas screen 6.
struct StatsView: View {
    @Environment(AppModel.self) private var model
    @State private var range: StatsRange = .week

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("Range", selection: $range) {
                    ForEach(StatsRange.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                DeviceActivityReport(range.context, filter: range.filter)
                    .frame(height: 640)

                focusCardStats
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Stats")
    }

    private var focusCardStats: some View {
        let stats = model.focusStats(days: range.days)
        let change = stats.timeLocked - stats.previousTimeLocked
        return VStack(alignment: .leading, spacing: 0) {
            Text("Focus Card")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 14)
                .padding(.bottom, 4)
            row("Time locked", value: Self.duration(stats.timeLocked),
                note: stats.previousTimeLocked > 0 ? "\(change < 0 ? "↓" : "↑") \(Self.duration(abs(change)))" : nil)
            Divider()
            row("Streak", value: stats.streakDays == 1 ? "1 day" : "\(stats.streakDays) days", note: nil)
            Divider()
            row("Emergency unlocks used",
                value: range == .week ? "\(model.emergencyUsedThisWeek) of \(model.emergencyAllowance)" : "\(stats.emergencyUsed)",
                note: nil)
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
            if let note { Text(note).foregroundStyle(.secondary) }
        }
        .padding(.vertical, 12)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
