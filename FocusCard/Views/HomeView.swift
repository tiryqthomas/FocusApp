import DeviceActivity
import SwiftUI

/// Canvas screen 1: Home, unlocked.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: FocusMode?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.cards.isEmpty {
                NavigationLink { CardsView() } label: {
                    HStack {
                        Text("Pair a card to start locking.")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(16)
                    .glassEffect(.regular, in: .capsule)
                }
                .buttonStyle(.plain)
            }

            NavigationLink { StatsView() } label: { StatsSummaryCard() }
                .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text("Unlocked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Choose a mode")
                    .font(.largeTitle.bold())
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(model.modes) { mode in
                        Button {
                            model.selectedModeID = mode.id
                        } label: {
                            ModeRow(mode: mode, selected: mode.id == model.selectedModeID)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { editing = mode }
                            Button("Delete", systemImage: "trash", role: .destructive) { model.deleteMode(mode) }
                        }
                    }
                    Button {
                        editing = FocusMode(name: "")
                    } label: {
                        Text("New mode")
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .overlay(Capsule().strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            HStack {
                Text("Emergency unlocks")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(model.emergencyLeft) of \(model.emergencyAllowance)")
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .padding(.horizontal, 6)

            Button {
                Task { await model.lockSelected() }
            } label: {
                Label("Lock \(model.selectedMode?.name ?? "")", systemImage: "lock.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.selectedMode == nil)
        }
        .padding(20)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink { CardsView() } label: { Image(systemName: "creditcard") }
                    .accessibilityLabel("Cards")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
        }
        .sheet(item: $editing) { mode in
            ModeEditView(mode: mode)
        }
    }
}

struct ModeRow: View {
    let mode: FocusMode
    let selected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.name)
                    .font(.title3.weight(.semibold))
                Text(mode.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(18)
        .contentShape(.rect)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.primary, lineWidth: selected ? 2 : 0)
        )
        .animation(.spring(duration: 0.3), value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Home's stats card. The numbers are drawn by the Screen Time report extension.
struct StatsSummaryCard: View {
    var body: some View {
        DeviceActivityReport(.summary, filter: StatsRange.week.filter)
            .frame(height: 84)
            .allowsHitTesting(false)
            .padding(18)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .accessibilityLabel("Screen time stats")
    }
}
