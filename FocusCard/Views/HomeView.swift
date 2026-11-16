import DeviceActivity
import FamilyControls
import SwiftUI

/// Canvas screen 1: Focus, unlocked.
/// Modes are a vertical list of pills, like Apple's Focus screen. Tap a pill to
/// select it. The three dots change its blocked apps, name and schedule, or delete it.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: FocusMode?
    @State private var pickingApps = false
    @State private var pickSelection = FamilyActivitySelection()
    @State private var pickingModeID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
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

            VStack(alignment: .leading, spacing: 2) {
                Text("Unlocked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Focus")
                    .font(.largeTitle.bold())
            }

            VStack(spacing: 10) {
                ForEach(model.modes) { mode in
                    ModePill(
                        mode: mode,
                        selected: mode.id == model.selectedModeID,
                        onSelect: { model.selectedModeID = mode.id },
                        onChangeApps: { startPicking(mode) },
                        onEdit: { editing = mode },
                        onDelete: { model.deleteMode(mode) }
                    )
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

            Spacer(minLength: 0)

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
        // Apple's picker: apps, categories and websites.
        .familyActivityPicker(isPresented: $pickingApps, selection: $pickSelection)
        .sensoryFeedback(.selection, trigger: model.selectedModeID)
        .onChange(of: pickingApps) { _, isOpen in
            guard !isOpen, let id = pickingModeID,
                  var mode = model.modes.first(where: { $0.id == id })
            else { return }
            mode.selection = pickSelection
            model.saveMode(mode)
            pickingModeID = nil
        }
    }

    private func startPicking(_ mode: FocusMode) {
        pickingModeID = mode.id
        pickSelection = mode.selection
        pickingApps = true
    }
}

/// One mode as a pill. The row selects it; the three dots open its options.
struct ModePill: View {
    let mode: FocusMode
    let selected: Bool
    let onSelect: () -> Void
    let onChangeApps: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onSelect) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(selected ? Color.primary : Color.secondary.opacity(0.18))
                        Image(systemName: "lock.fill")
                            .foregroundStyle(selected ? Color(.systemBackground) : Color.primary)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.name)
                            .font(.headline)
                        Text(mode.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])

            Menu {
                Button("Change blocked apps", systemImage: "app.badge.checkmark", action: onChangeApps)
                Button("Name and schedule", systemImage: "pencil", action: onEdit)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .frame(width: 40, height: 40)
                    .contentShape(.circle)
            }
            .accessibilityLabel("\(mode.name) options")
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.primary, lineWidth: selected ? 2 : 0)
        )
        .animation(.spring(duration: 0.3), value: selected)
    }
}

/// Home's stats card. The numbers are drawn by the Screen Time report extension.
struct StatsSummaryCard: View {
    var body: some View {
        DeviceActivityReport(.summary, filter: StatsRange.week.filter())
            .frame(height: 84)
            .allowsHitTesting(false)
            .padding(18)
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
            .accessibilityLabel("Screen time stats")
    }
}
