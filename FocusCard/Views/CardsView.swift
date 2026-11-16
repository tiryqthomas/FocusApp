import SwiftUI

/// Pair and remove cards, all inside the app. Any paired card works for any mode (Decision 8).
struct CardsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            if model.cards.isEmpty {
                Text("No cards paired.")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach(model.cards) { card in
                        LabeledContent {
                            Text("•••• \(String(card.tagID.suffix(4)))")
                                .font(Theme.lcdFont(17))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(card.name)
                                Text(card.added.formatted(date: .abbreviated, time: .omitted))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { model.removeCards(at: $0) }
                    .deleteDisabled(model.lock != nil)
                } footer: {
                    Text("Any paired card locks and unlocks every mode.")
                }
            }
            Section {
                Button {
                    Task { await model.pairCard() }
                } label: {
                    Label("Pair a card", systemImage: "wave.3.right")
                }
                .buttonStyle(PrimaryButtonStyle())
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .animation(.spring(duration: 0.35), value: model.cards)
        .lcdForm()
        .navigationTitle("Cards")
        .navigationBarTitleDisplayMode(.inline)
    }
}
