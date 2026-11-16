import DeviceActivity
import FamilyControls
import SwiftUI

/// Canvas screen 1: Focus, unlocked.
/// Modes are a list of rows. Tap a row to select it. The "..." button changes its
/// blocked apps, name and schedule, or deletes it. Cards and Settings sit in the
/// bottom bar, like the softkeys on an old handset.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: FocusMode?
    @State private var pickingApps = false
    @State private var pickSelection = FamilyActivitySelection()
    @State private var pickingModeID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.cards.isEmpty {
                NavigationLink { CardsView() } label: {
                    HStack {
                        Text("Pair a card to start locking.")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(14)
                    .lcdPanel()
                }
                .buttonStyle(.plain)
            }

            NavigationLink { StatsView() } label: { StatsSummaryCard() }
                .buttonStyle(.plain)

            Text("Modes")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            VStack(spacing: 0) {
                ForEach(model.modes) { mode in
                    ModeRow(
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
                    Text("+ New mode")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .lcdPanel()
            .animation(.spring(duration: 0.35), value: model.modes)

            Spacer(minLength: 0)

            HStack {
                Text("Emergency unlocks")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(model.emergencyLeft) of \(model.emergencyAllowance)")
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
            }
            .font(.footnote)

            Button {
                Task { await model.lockSelected() }
            } label: {
                Label("Lock \(model.selectedMode?.name ?? "")", systemImage: "lock.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.selectedMode == nil)
        }
        .padding(14)
        .lcdScreen()
        .navigationTitle("Focus")
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
        .sheet(item: $editing) { mode in
            ModeEditView(mode: mode)
        }
        // Apple's picker: apps, categories and websites.
        .familyActivityPicker(isPresented: $pickingApps, selection: $pickSelection)
        .haptic(.selection, trigger: model.selectedModeID)
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

/// One mode as a row. The row selects it; the "..." button opens its options.
struct ModeRow: View {
    let mode: FocusMode
    let selected: Bool
    let onSelect: () -> Void
    let onChangeApps: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.name)
                            .font(.headline)
                        Text(mode.detail)
                            .font(.caption)
                            .opacity(selected ? 0.85 : 0.6)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])

            Menu {
                Button("Change blocked apps", systemImage: "app.badge.checkmark", action: onChangeApps)
                Button("Name and schedule", systemImage: "pencil", action: onEdit)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Text("...")
                    .font(.headline)
                    .frame(width: 40, height: 32)
                    .overlay(Rectangle().strokeBorder(selected ? Color.white : Theme.buttonLine, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(mode.name) options")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background(selected ? Theme.blue : Theme.panel)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
        .animation(.spring(duration: 0.3), value: selected)
    }
}

/// Home's stats card. The numbers are drawn by the Screen Time report extension.
struct StatsSummaryCard: View {
    var body: some View {
        DeviceActivityReport(.summary, filter: StatsRange.week.filter())
            .frame(height: 84)
            .allowsHitTesting(false)
            .padding(14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .lcdPanel()
            .accessibilityLabel("Screen time stats")
    }
}
