import SwiftUI

/// Press and hold for 5 seconds, then confirm. Uses one of the week's emergency unlocks.
struct EmergencyUnlockView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var pressStart: Date?
    @State private var confirming = false

    private let holdSeconds: Double = 5

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Emergency unlock")
                .font(.title.weight(.semibold))
            Text("Press and hold for 5 seconds.\n\(model.emergencyLeft) of \(model.emergencyAllowance) left this week.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            TimelineView(.periodic(from: .now, by: 0.05)) { context in
                let progress = elapsed(at: context.date) / holdSeconds
                ZStack {
                    Circle().stroke(.white.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(max(0, Int((holdSeconds - elapsed(at: context.date)).rounded(.up))))")
                        .font(.system(size: 56, weight: .light))
                        .monospacedDigit()
                }
            }
            .frame(width: 180, height: 180)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: holdSeconds, maximumDistance: 60) {
                pressStart = nil
                confirming = true
            } onPressingChanged: { pressing in
                pressStart = pressing ? .now : nil
            }
            .sensoryFeedback(.warning, trigger: confirming) { _, new in new }
            .accessibilityElement()
            .accessibilityLabel("Press and hold to unlock")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { confirming = true }

            Text("Let go to cancel")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .background(Color.black.ignoresSafeArea())
        .alert("Are you sure?", isPresented: $confirming) {
            Button("Stay locked", role: .cancel) {}
            Button("Unlock", role: .destructive) {
                model.emergencyUnlock()
                dismiss()
            }
        } message: {
            Text("This unlocks now. You'll have \(max(0, model.emergencyLeft - 1)) of \(model.emergencyAllowance) emergency unlocks left until Monday.")
        }
    }

    private func elapsed(at date: Date) -> Double {
        guard let pressStart else { return 0 }
        return min(holdSeconds, max(0, date.timeIntervalSince(pressStart)))
    }
}
