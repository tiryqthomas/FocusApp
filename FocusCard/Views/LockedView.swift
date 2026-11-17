import SwiftUI

/// Locked: the whole app is black with a timer. The card unlocks; so do an
/// emergency unlock (limited each week) or the recovery code.
struct LockedView: View {
    @Environment(AppModel.self) private var model
    @State private var showEmergency = false
    @State private var showRecovery = false

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(isPresented: $showEmergency) { EmergencyUnlockView() }
                .navigationDestination(isPresented: $showRecovery) { RecoveryUnlockView() }
                .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.colorScheme, .dark)
    }

    private var content: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 56))
            if let lock = model.lock {
                Text("\(lock.modeName) is locked")
                    .font(.title2.weight(.semibold))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Self.elapsed(from: lock.since, to: context.date))
                        .font(.system(size: 56, weight: .light))
                        .monospacedDigit()
                }
            }
            Text(model.mode.selectionSummary + " blocked")
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await model.scanToToggle() }
            } label: {
                Label("Scan card to unlock", systemImage: "wave.3.right")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .controlSize(.large)

            Button("Emergency unlock (\(model.emergencyLeft) left)") { showEmergency = true }
                .disabled(model.emergencyLeft == 0)
                .frame(height: 36)
            Button("Lost card or scan not working?") { showRecovery = true }
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
    }

    /// "1:24:08"
    static func elapsed(from start: Date, to now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
