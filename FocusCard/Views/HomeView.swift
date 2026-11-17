import Charts
import FamilyControls
import SwiftUI

/// Unlocked: screen time chart, the mode, details, and the Lock button.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false
    @State private var selection = FamilyActivitySelection()
    @State private var range: StatsRange = .week
    @State private var showStats = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 14) {
            ScreenTimeCard(range: $range) { showStats = true }

            ModePill(name: model.mode.name, systemImage: "briefcase", selected: true)

            details

            Spacer(minLength: 0)

            Button {
                Task { await model.scanToToggle() }
            } label: {
                Label("Lock \(model.mode.name)", systemImage: "lock.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(.systemBackground))
            .background(Color.primary, in: Capsule())
            .sensoryFeedback(.impact, trigger: model.lock)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
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
        .familyActivityPicker(isPresented: $picking, selection: $selection)
        // Save whenever the picked list changes, and again when the picker closes,
        // so the new list is never lost to the order these two updates arrive in.
        .onChange(of: selection) { _, newValue in
            model.saveSelection(newValue)
        }
        .onChange(of: picking) { _, isOpen in
            if !isOpen { model.saveSelection(selection) }
        }
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
                        Text("Allow").foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
                Divider()
            }
            Button {
                selection = model.mode.selection
                picking = true
            } label: {
                DetailRow(label: "Blocked", chevron: true) {
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
                            .fill(model.card == nil ? Color(.systemGray3) : .blue)
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
struct ModePill: View {
    let name: String
    let systemImage: String
    let selected: Bool

    var body: some View {
        HStack {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(selected ? Color.blue : Color.primary)
                .frame(width: 44)
            Spacer()
            Text(name).font(.headline)
            Spacer()
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(selected ? Color(.tertiarySystemFill) : .clear, in: Circle())
                .frame(width: 44)
        }
        .padding(.horizontal, 6)
        .frame(height: 54)
        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
        .overlay {
            if selected { Capsule().strokeBorder(.blue, lineWidth: 2) }
        }
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
