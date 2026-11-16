import SwiftUI

/// Canvas screen 4: the whole app turns black while locked (Decision 9).
struct LockedView: View {
    @Environment(AppModel.self) private var model
    @State private var showEmergency = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 48, weight: .light))
                    .frame(width: 132, height: 132)
                    .glassEffect(.regular, in: .circle)
                if let lock = model.lock {
                    Text("\(lock.modeName) is locked")
                        .foregroundStyle(.secondary)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Self.elapsed(from: lock.since, to: context.date))
                            .font(.system(size: 56, weight: .light))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                if let mode = model.lockedMode {
                    Text("\(mode.selectionSummary) blocked")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await model.unlockWithCard() }
                } label: {
                    Label("Unlock with card", systemImage: "lock.open.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Emergency unlock · \(model.emergencyLeft) left this week") {
                    showEmergency = true
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(height: 44)
                .disabled(model.emergencyLeft == 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationDestination(isPresented: $showEmergency) {
                EmergencyUnlockView()
            }
        }
        .environment(\.colorScheme, .dark)
    }

    /// "1:24:08"
    static func elapsed(from start: Date, to now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
