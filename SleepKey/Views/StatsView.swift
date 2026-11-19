import SwiftUI

/// Night stats: Week or Month, from the nights SleepKey has recorded on this iPhone.
struct StatsView: View {
    @Environment(AppModel.self) private var model
    @State private var range: Range = .week

    enum Range: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        var id: String { rawValue }
        var days: Int { self == .week ? 7 : 28 }
    }

    var body: some View {
        let stats = model.nightStats(days: range.days)
        ScrollView {
            VStack(spacing: 14) {
                LCDSegment(options: Range.allCases, title: { $0.rawValue }, selection: $range)

                HStack(spacing: 12) {
                    tile("Phone-free nights", "\(stats.nightsCompleted) of \(range.days)")
                    tile("Current streak", stats.streak == 1 ? "1 night" : "\(stats.streak) nights")
                }

                VStack(alignment: .leading, spacing: 0) {
                    row("Average night locked", value: Self.hours(stats.averageHoursLocked))
                    Divider()
                    row("Emergency unlocks used",
                        value: range == .week
                            ? "\(model.emergencyUsedThisWeek) of \(model.emergencyAllowance)"
                            : "\(stats.emergencyUsed)")
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lcdPanel()

                Text("Screen time after bedtime and time to first social app are not tracked yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .lcdScreen()
        .lcdNavigationBar()
        .navigationTitle("Night stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lcdPanel()
    }

    private func row(_ name: String, value: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .padding(.vertical, 14)
    }

    static func hours(_ value: Double) -> String {
        let minutes = Int((value * 60).rounded())
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
