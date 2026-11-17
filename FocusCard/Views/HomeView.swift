import FamilyControls
import SwiftUI

/// Unlocked: today's rings, this week's focus, the mode, details, and the Lock button.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var picking = false
    @State private var pickingModeID: UUID?
    @State private var selection = FamilyActivitySelection()
    @State private var showStats = false
    @State private var showSettings = false
    @State private var editing: FocusMode?
    /// Rings start empty and spring to their values when Home appears.
    @State private var ringsIn = false

    /// One spacing value between every block on the main screens.
    static let spacing = Theme.spacing

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacing) {
                header
                rings
                WeekFocusCard { showStats = true }
                modes
                details
            }
            .padding(.horizontal, Theme.spacing)
            .padding(.top, Theme.groupSpacing)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await model.scanToToggle() }
            } label: {
                Label("Lock \(model.mode.name)", systemImage: "lock.fill")
            }
            .buttonStyle(CapsuleButtonStyle(fill: Theme.focus, text: .black))
            .haptic(.impact, enabled: model.hapticsOn, trigger: model.lock)
            .padding(.horizontal, Theme.spacing)
            .padding(.vertical, Theme.groupSpacing)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showStats) {
            StatsView(initialRange: .week)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(item: $editing) { mode in
            ModeEditView(mode: mode)
        }
        .familyActivityPicker(isPresented: $picking, selection: $selection)
        // Save whenever the picked list changes, and again when the picker closes,
        // so the new list is never lost to the order these two updates arrive in.
        .onChange(of: selection) { _, newValue in
            if let id = pickingModeID { model.saveSelection(newValue, for: id) }
        }
        .onChange(of: picking) { _, isOpen in
            if !isOpen, let id = pickingModeID { model.saveSelection(selection, for: id) }
        }
        .onAppear {
            guard !ringsIn else { return }
            if reduceMotion {
                ringsIn = true
            } else {
                withAnimation(.spring(duration: 0.9, bounce: 0.25).delay(0.15)) { ringsIn = true }
            }
        }
        .haptic(.impact(weight: .light), enabled: model.hapticsOn && !reduceMotion, trigger: ringsIn)
    }

    private func pickApps(for mode: FocusMode) {
        pickingModeID = mode.id
        selection = mode.selection
        picking = true
    }

    /// Date, "Today", and Settings.
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(.secondary)
                Text("Today")
                    .font(.largeTitle.bold())
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: Theme.pillHeight, height: Theme.pillHeight)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Settings")
        }
        .padding(.top, Theme.groupSpacing)
    }

    /// Focused, Screen and Pickups for today. Tapping opens Stats.
    private var rings: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let focused = model.focusedToday(now: context.date)
            let screen = SampleStats.headline(.day)
            HStack(spacing: Theme.groupSpacing) {
                StatRing(
                    progress: ringsIn ? focused / SampleStats.focusGoalSeconds : 0,
                    color: Theme.focus,
                    value: Self.clock(seconds: focused),
                    label: "Focused"
                )
                StatRing(
                    progress: ringsIn ? screen / SampleStats.screenLimitMinutes : 0,
                    color: Theme.screen,
                    value: Self.clock(seconds: screen * 60),
                    label: "Screen"
                )
                StatRing(
                    progress: ringsIn ? Double(SampleStats.pickupsToday) / SampleStats.pickupsLimit : 0,
                    color: Theme.pickups,
                    value: "\(SampleStats.pickupsToday)",
                    label: "Pickups"
                )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showStats = true }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens Stats")
    }

    /// Every mode as a pill in one row; the selected one is solid. The menu edits the selected mode.
    private var modes: some View {
        VStack(spacing: Theme.groupSpacing) {
            HStack {
                SectionLabel("Focus Mode")
                Menu {
                    Button("Change Blocked Apps", systemImage: "app.badge.checkmark") { pickApps(for: model.mode) }
                        .disabled(!model.isAuthorized)
                    Button("Edit Name and Icon", systemImage: "pencil") { editing = model.mode }
                    if model.modes.count > 1 {
                        Button("Delete \(model.mode.name)", systemImage: "trash", role: .destructive) { model.deleteMode(model.mode) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: Theme.pillHeight, height: 24)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("\(model.mode.name) options")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.groupSpacing) {
                    ForEach(model.modes) { mode in
                        ModeChip(mode: mode, selected: mode.id == model.mode.id) {
                            model.select(mode)
                        }
                    }
                    Button {
                        editing = FocusMode(name: "", symbol: "sparkles")
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: Theme.pillHeight, height: Theme.pillHeight)
                    }
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("New Focus")
                }
            }
            .scrollClipDisabled()
        }
        .animation(.snappy, value: model.modes)
        .animation(.snappy, value: model.selectedModeID)
        .haptic(.selection, enabled: model.hapticsOn, trigger: model.selectedModeID)
    }

    /// Label and value rows: Screen Time access (until allowed), blocked apps, streak, card (until paired).
    private var details: some View {
        VStack(spacing: 0) {
            if !model.isAuthorized {
                Button {
                    Task { await model.requestAuthorization() }
                } label: {
                    DetailRow(label: "Screen Time", chevron: true) {
                        Text("Allow").foregroundStyle(.tint)
                    }
                }
                .buttonStyle(.plain)
                RowDivider()
            }
            Button {
                pickApps(for: model.mode)
            } label: {
                DetailRow(label: "Blocked in \(model.mode.name)", chevron: true) {
                    Text(model.mode.selectionSummary)
                }
            }
            .buttonStyle(.plain)
            .disabled(!model.isAuthorized)
            RowDivider()
            TimelineView(.periodic(from: .now, by: 60)) { context in
                DetailRow(label: "Streak") {
                    let days = model.focusLog.streak(now: context.date)
                    Text(days == 1 ? "1 day" : "\(days) days")
                }
            }
            if model.card == nil {
                RowDivider()
                Button {
                    Task { await model.pairCard() }
                } label: {
                    DetailRow(label: "Card", chevron: true) {
                        Text("Pair a Card").foregroundStyle(.tint)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .card(padding: 0)
    }

    /// "2:14" from seconds (hours and minutes).
    static func clock(seconds: Double) -> String {
        let m = Int(seconds / 60)
        return String(format: "%d:%02d", m / 60, m % 60)
    }
}

/// A hairline between rows, inset to line up with the row text.
struct RowDivider: View {
    var body: some View { Divider().padding(.leading, Theme.cardPadding) }
}

/// One mode as a capsule. Selected is solid; the rest are glass.
struct ModeChip: View {
    let mode: FocusMode
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Label(mode.name, systemImage: mode.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color(.systemBackground) : Color.primary)
                .padding(.horizontal, Theme.spacing)
                .frame(height: Theme.pillHeight)
                .background {
                    if selected { Capsule().fill(Color.primary) }
                }
        }
        .buttonStyle(.plain)
        .glassEffect(selected ? .identity : .regular.interactive(), in: .capsule)
        .accessibilityLabel("\(mode.name), \(mode.selectionSummary)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// Locked time each day this week, today in green, against last week. Tapping opens Stats.
struct WeekFocusCard: View {
    @Environment(AppModel.self) private var model
    let openStats: () -> Void

    private static let days = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let values = model.focusedByDayThisWeek(now: context.date)
            let total = values.reduce(0, +)
            let last = model.focusedLastWeekSoFar(now: context.date)
            let top = max(values.max() ?? 0, 1)
            let today = (Calendar.current.component(.weekday, from: context.date) + 5) % 7

            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("FOCUSED THIS WEEK")
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Spacer()
                    change(total: total, last: last)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: Theme.groupSpacing) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(i == today ? Theme.focus : Color(.systemGray4))
                                .frame(height: max(6, 72 * values[i] / top))
                                .frame(height: 72, alignment: .bottom)
                            Text(Self.days[i])
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .animation(.snappy, value: values)
            }
            .card()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: openStats)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens Stats")
    }

    @ViewBuilder
    private func change(total: Double, last: Double) -> some View {
        if last > 0 {
            let percent = Int(((total - last) / last * 100).rounded())
            Text(percent >= 0 ? "▲ \(percent)% vs last week" : "▼ \(-percent)% vs last week")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(percent >= 0 ? Theme.focus : Color.secondary)
        } else {
            Text(formatDuration(total))
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
    }
}

/// One label and value row, 48 points tall, inset by the card padding.
struct DetailRow<Value: View>: View {
    let label: String
    var chevron = false
    @ViewBuilder let value: Value

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            value.fontWeight(.semibold).monospacedDigit()
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.subheadline)
        .frame(minHeight: Theme.rowHeight)
        .padding(.horizontal, Theme.cardPadding)
        .contentShape(Rectangle())
    }
}
