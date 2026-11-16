import SwiftUI

/// Canvas screens 7 and 8: press and hold for 5 seconds, then confirm (Decision 11).
struct EmergencyUnlockView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var pressStart: Date?
    @State private var confirming = false

    private let holdSeconds: Double = 5

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("Emergency unlock")
                .font(.title.bold())
            Text("Press and hold for 5 seconds.")
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                TimelineView(.periodic(from: .now, by: 0.1)) { context in
                    Text("\(secondsLeft(at: context.date))")
                        .font(.system(size: 44, weight: .light))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            .frame(width: 168, height: 168)
            .glassEffect(.regular, in: .circle)
            .contentShape(.circle)
            .onLongPressGesture(minimumDuration: holdSeconds, maximumDistance: 60) {
                pressStart = nil
                confirming = true
            } onPressingChanged: { pressing in
                if pressing {
                    pressStart = .now
                    withAnimation(.linear(duration: holdSeconds)) { progress = 1 }
                } else {
                    let held = pressStart.map { Date.now.timeIntervalSince($0) } ?? 0
                    guard held < holdSeconds - 0.1 else { return }
                    pressStart = nil
                    withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) { progress = 0 }
                }
            }
            .sensoryFeedback(.warning, trigger: confirming) { _, new in new }
            .accessibilityElement()
            .accessibilityLabel("Press and hold to unlock")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { confirming = true }

            Text("Let go to cancel")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.black.ignoresSafeArea())
        .alert("Are you sure?", isPresented: $confirming) {
            Button("Stay locked", role: .cancel) {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) { progress = 0 }
            }
            Button("Unlock", role: .destructive) {
                model.emergencyUnlock()
            }
        } message: {
            Text("\(model.lock?.modeName ?? "This mode") will unlock now. You will have \(max(0, model.emergencyLeft - 1)) of \(model.emergencyAllowance) emergency unlocks left until Monday.")
        }
    }

    private func secondsLeft(at date: Date) -> Int {
        guard let pressStart else { return Int(holdSeconds) }
        return max(0, Int((holdSeconds - date.timeIntervalSince(pressStart)).rounded(.up)))
    }
}
