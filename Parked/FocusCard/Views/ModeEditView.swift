import FamilyControls
import SwiftUI

/// Canvas screen 2: edit a mode.
struct ModeEditView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var mode: FocusMode
    @State private var picking = false
    @State private var confirmDelete = false
    @State private var confirmLeave = false
    private let original: FocusMode

    init(mode: FocusMode) {
        _mode = State(initialValue: mode)
        original = mode
    }

    private var isNew: Bool { !model.modes.contains { $0.id == mode.id } }
    private var hasChanges: Bool { mode != original }
    private var canSave: Bool { !mode.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $mode.name)
                }
                Section {
                    Button {
                        picking = true
                    } label: {
                        LabeledContent("Blocked apps", value: mode.selectionSummary)
                    }
                    .foregroundStyle(.primary)
                    Toggle("Start on schedule", isOn: $mode.scheduleEnabled.animation())
                    if mode.scheduleEnabled {
                        DatePicker("Starts", selection: startTime, displayedComponents: .hourAndMinute)
                        LabeledContent("Days", value: "Every day")
                    }
                } footer: {
                    if mode.scheduleEnabled {
                        Text("A scheduled mode still needs a card to unlock.")
                    }
                }
                if !isNew {
                    Section {
                        Button("Delete mode", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .lcdForm()
            .navigationTitle(isNew ? "New mode" : original.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { confirmLeave = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .familyActivityPicker(isPresented: $picking, selection: $mode.selection)
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog("Delete \(original.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    model.deleteMode(original)
                    dismiss()
                }
            }
            // Leaving part-way: Stay, Save or Discard, so nothing is lost by accident.
            .confirmationDialog("Save your changes?", isPresented: $confirmLeave, titleVisibility: .visible) {
                if canSave {
                    Button("Save") { save() }
                }
                Button("Discard", role: .destructive) { dismiss() }
                Button("Stay", role: .cancel) {}
            }
        }
    }

    private func save() {
        mode.name = mode.name.trimmingCharacters(in: .whitespaces)
        model.saveMode(mode)
        dismiss()
    }

    private var startTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: mode.startHour, minute: mode.startMinute)) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                mode.startHour = parts.hour ?? 23
                mode.startMinute = parts.minute ?? 0
            }
        )
    }
}
