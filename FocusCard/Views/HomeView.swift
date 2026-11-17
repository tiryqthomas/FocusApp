import Charts
import FamilyControls
import SwiftUI

/// Unlocked: screen time chart, the mode, details, and the Lock button.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false
    @State private var pickingModeID: UUID?
    @State private var selection = FamilyActivitySelection()
    @State private var range: StatsRange = .week
    @State private var showStats = false
    @State private var showSettings = false
    @State private var editing: FocusMode?

    /// One spacing value between every block and button on this screen.
    static let spacing: CGFloat = 12

    var body: some View {
        ScrollView {
            VStack(spacing: Self.spacing) {
                ScreenTimeCard(range: $range) { showStats = true }

                modes

                details
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await model.scanToToggle() }
            } label: {
                Label("Lock \(model.mode.name)", systemImage: "lock.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .sensoryFeedback(.impact, trigger: model.lock)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text("Focus Card").font(.headline)
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .navigationDestination(isPresented: $showStats) {
            StatsView(initialRange: range)
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
    }

    private func pickApps(for mode: FocusMode) {
        pickingModeID = mode.id
        selection = mode.selection
        picking = true
    }

    /// Every mode as a pill. The selected one is tinted glass. "New Focus" adds one.
    private var modes: some View {
        VStack(spacing: Self.spacing) {
            ForEach(model.modes) { mode in
                ModePill(
                    mode: mode,
                    selected: mode.id == model.mode.id,
                    canDelete: model.modes.count > 1,
                    onSelect: { model.select(mode) },
                    onChangeApps: { pickApps(for: mode) },
                    onEdit: { editing = mode },
                    onDelete: { model.deleteMode(mode) }
                )
            }
            Button {
                editing = FocusMode(name: "", symbol: "sparkles")
            } label: {
                Label("New Focus", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .animation(.snappy, value: model.modes)
        .animation(.snappy, value: model.selectedModeID)
        .sensoryFeedback(.selection, trigger: model.selectedModeID)
    }

    /// Label and value rows: focus time, Screen Time access, blocked apps, card.
    private var details: some View {
        VStack(spacing: 0) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                DetailRow(label: "Today") {
                    Text(formatDuration(model.focusedToday(now: context.date)))
                }
            }
            Divider()
            if !model.isAuthorized {
                Button {
                    Task { await model.requestAuthorization() }
                } label: {
                    DetailRow(label: "Screen Time", chevron: true) {
                        Text("Allow").foregroundStyle(.tint)
                    }
                }
                .buttonStyle(.plain)
                Divider()
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
            Divider()
            Button {
                Task { await model.pairCard() }
            } label: {
                DetailRow(label: "Card", chevron: true) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(model.card == nil ? Color(.systemGray3) : .accentColor)
                            .frame(width: 8, height: 8)
                        Text(model.card == nil ? "Pair a card" : "Paired card")
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// One label and value row, 50 points tall.
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
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}

/// A Focus-style capsule: icon, name, and a three-dot menu.
/// Selected is tinted Liquid Glass; the rest are plain grouped capsules.
struct ModePill: View {
    let mode: FocusMode
    let selected: Bool
    let canDelete: Bool
    let onSelect: () -> Void
    let onChangeApps: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: mode.symbol)
                        .font(.title3)
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.name).font(.headline)
                        Text(mode.selectionSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(mode.name), \(mode.selectionSummary)")
            .accessibilityAddTraits(selected ? [.isSelected] : [])

            Menu {
                Button("Change Blocked Apps", systemImage: "app.badge.checkmark", action: onChangeApps)
                Button("Edit Name and Icon", systemImage: "pencil", action: onEdit)
                if canDelete {
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemFill), in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("\(mode.name) options")
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(height: 62)
        .background {
            if !selected {
                Capsule().fill(Color(.secondarySystemGroupedBackground))
            }
        }
        .glassEffect(selected ? .regular.tint(.accentColor.opacity(0.3)).interactive() : .identity, in: .capsule)
    }
}

/// Stacked screen time bars by category. Tapping the card (except the range
/// switch) opens Stats.
struct ScreenTimeCard: View {
    @Binding var range: StatsRange
    let openStats: () -> Void

    var body: some View {
        let average = SampleStats.headline(range)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(range == .day ? "TODAY" : "DAILY AVERAGE")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(SampleStats.format(minutes: average))
                        .font(.title.bold())
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(SampleStats.change(range))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: openStats)
                Picker("Range", selection: $range.animation(.snappy)) {
                    ForEach(StatsRange.allCases) { Text($0.short).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemFill), in: Circle())
                    .contentShape(Rectangle())
                    .onTapGesture(perform: openStats)
                    .accessibilityLabel("Open Stats")
                    .accessibilityAddTraits(.isButton)
            }

            Chart {
                ForEach(SampleStats.bars(range)) { bar in
                    BarMark(
                        x: .value("Time", bar.label),
                        y: .value("Minutes", bar.minutes)
                    )
                    .foregroundStyle(bar.category.color)
                }
                RuleMark(y: .value("Average", range == .day ? average / 24 : average))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
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
            .frame(height: 118)
            .contentShape(Rectangle())
            .onTapGesture(perform: openStats)

            CategoryLegend(range: range)
                .contentShape(Rectangle())
                .onTapGesture(perform: openStats)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Colour key with each category's average.
struct CategoryLegend: View {
    let range: StatsRange

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 4) {
            ForEach(SampleStats.Category.allCases) { category in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(category.color)
                        .frame(width: 8, height: 8)
                    Text(category.name).foregroundStyle(.secondary)
                    Text(SampleStats.format(minutes: SampleStats.headline(range, category: category)))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .font(.caption)
            }
        }
    }
}
