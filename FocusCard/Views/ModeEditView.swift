import FamilyControls
import SwiftUI

/// Make a new Focus mode, or change one's name, icon and blocked apps.
struct ModeEditView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var mode: FocusMode
    @State private var picking = false
    private let isNew: Bool

    init(mode: FocusMode) {
        _mode = State(initialValue: mode)
        isNew = mode.name.isEmpty
    }

    private var canSave: Bool { !mode.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Reading, Gym, Family…", text: $mode.name)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(FocusMode.symbols, id: \.self) { symbol in
                            let chosen = symbol == mode.symbol
                            Button {
                                mode.symbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .foregroundStyle(chosen ? Color.accentColor : Color.primary)
                                    .frame(width: 44, height: 44)
                                    .background(chosen ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
                            .accessibilityAddTraits(chosen ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        picking = true
                    } label: {
                        LabeledContent("Blocked apps", value: mode.selectionSummary)
                    }
                    .foregroundStyle(.primary)
                    .disabled(!model.isAuthorized)
                } footer: {
                    if !model.isAuthorized { Text("Allow Screen Time on the home screen first.") }
                }
            }
            .navigationTitle(isNew ? "New Focus" : "Edit Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") {
                        mode.name = mode.name.trimmingCharacters(in: .whitespaces)
                        model.saveMode(mode)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .familyActivityPicker(isPresented: $picking, selection: $mode.selection)
        }
    }
}
