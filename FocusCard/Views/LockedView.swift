import SwiftUI

/// Locked: the whole app is black with a timer. Only the card unlocks.
struct LockedView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }

    /// "1:24:08"
    static func elapsed(from start: Date, to now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
