import FamilyControls
import SwiftUI

/// Unlocked: set up Screen Time, the card and the apps, then scan to lock.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var picking = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        List {
            Section("Setup") {
                if model.isAuthorized {
                    Label("Screen Time allowed", systemImage: "checkmark.circle.fill")
                } else {
                    Button {
                        Task { await model.requestAuthorization() }
                    } label: {
                        Label("Allow Screen Time", systemImage: "hourglass")
                    }
                }

                Button {
                    Task { await model.pairCard() }
                } label: {
                    LabeledContent {
                        Text(model.card.map { "•••• \($0.tagID.suffix(4))" } ?? "Not paired")
                    } label: {
                        Label(model.card == nil ? "Pair card" : "Replace card", systemImage: "wave.3.right")
                    }
                }

                Button {
                    selection = model.mode.selection
                    picking = true
                } label: {
                    LabeledContent {
                        Text(model.mode.selectionSummary)
                    } label: {
                        Label("Blocked apps", systemImage: "app.badge.checkmark")
                    }
                }
                .disabled(!model.isAuthorized)
            }
        }
        .navigationTitle(model.mode.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await model.scanToToggle() }
            } label: {
                Label("Scan card to lock", systemImage: "lock.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
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
}
