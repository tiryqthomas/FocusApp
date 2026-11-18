import SwiftUI

/// Home: tonight's plan, the streak, night stats, and a daytime "Lock now".
/// Cards and Settings sit in the bottom bar, like softkeys on an old handset.
struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if model.cards.isEmpty {
                    NavigationLink { CardsView() } label: {
                        banner("Pair a card so you can unlock in the morning.")
                    }
                    .buttonStyle(.plain)
                }
                if model.night.isEmpty {
                    NavigationLink { NightSetupView() } label: {
                        banner("Choose what to lock at bedtime.")
                    }
                    .buttonStyle(.plain)
                }

                tonightCard
                streakCard

                NavigationLink { StatsView() } label: {
                    HStack {
                        Text("Night stats")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .lcdPanel()
                }
                .buttonStyle(.plain)

                HStack {
                    Text("Emergency unlocks")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(model.emergencyLeft) of \(model.emergencyAllowance)")
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                }
                .font(.footnote)
                .padding(.top, 4)

                Button {
                    Task { await model.lockNow() }
                } label: {
                    Label("Lock now (tap card)", systemImage: "lock.fill")
                }
                .buttonStyle(SecondaryButtonStyle())

                Text("For daytime use, same apps and websites.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(14)
        }
        .lcdScreen()
        .navigationTitle("Keycard")
        .navigationBarTitleDisplayMode(.inline)
        .lcdNavigationBar()
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                NavigationLink("Cards") { CardsView() }
                Spacer()
                NavigationLink("Settings") { SettingsView() }
            }
        }
        .toolbarBackground(Theme.bar, for: .bottomBar)
        .toolbarBackground(.visible, for: .bottomBar)
    }

    private var tonightCard: some View {
        let night = model.night
        return VStack(alignment: .leading, spacing: 12) {
            Text("Tonight")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text("Locks in \(Self.span(from: context.date, to: night.nextBedtime(after: context.date)))")
                    .font(.largeTitle.bold())
                    .contentTransition(.numericText())
            }
            HStack(spacing: 12) {
                timeBox("Bedtime", night.startTimeText)
                timeBox("Wake", night.wakeTimeText)
            }
            Text(night.selectionSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lcdPanel()
    }

    private var streakCard: some View {
        let nights = model.lastSevenNights()
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Phone-free nights")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(model.streak() == 1 ? "1 in a row" : "\(model.streak()) in a row")
                    .font(.title.bold())
            }
            Spacer()
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(nights.enumerated()), id: \.offset) { _, done in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(done ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: 10, height: 28)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .lcdPanel()
    }

    private func timeBox(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lcd)
    }

    private func banner(_ text: String) -> some View {
        HStack {
            Text(text)
            Spacer()
            Image(systemName: "chevron.right")
        }
        .font(.subheadline.weight(.medium))
        .padding(14)
        .lcdPanel()
    }

    /// "3h 12m" or "42m"
    static func span(from start: Date, to end: Date) -> String {
        let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}
