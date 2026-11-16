import SwiftUI

/// Canvas screens 7 and 8: press and hold for 5 seconds, then confirm (Decision 11).
/// A square box fills with five blocks while you hold. Letting go early shakes it.
struct EmergencyUnlockView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressStart: Date?
    @State private var confirming = false
    @State private var cancelCount = 0
    @State private var ticks = 0
    @State private var tickTask: Task<Void, Never>?

    private let holdSeconds: Double = 5

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Text("EMERGENCY UNLOCK")
                .font(Theme.lcdFont(26))
                .tracking(2)
            Text("PRESS AND HOLD FOR 5 SECONDS")
                .font(Theme.lcdFont(16))
                .opacity(0.8)

            holdBox
                .phaseAnimator([0.0, -10.0, 10.0, -6.0, 6.0, 0.0], trigger: cancelCount) { view, offset in
                    view.offset(x: reduceMotion ? 0 : offset)
                } animation: { _ in .linear(duration: 0.06) }
                .sensoryFeedback(.warning, trigger: confirming) { _, new in new }
                .sensoryFeedback(.selection, trigger: ticks)
                .accessibilityElement()
                .accessibilityLabel("Press and hold to unlock")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { confirming = true }

            Text("LET GO TO CANCEL")
                .font(Theme.lcdFont(16))
                .opacity(0.8)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .blackScreen()
        .navigationBarBackButtonHidden(false)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Are you sure?", isPresented: $confirming) {
            Button("Stay locked", role: .cancel) {}
            Button("Unlock", role: .destructive) {
                model.emergencyUnlock()
            }
        } message: {
            Text("\(model.lock?.modeName ?? "This mode") will unlock now. You will have \(max(0, model.emergencyLeft - 1)) of \(model.emergencyAllowance) emergency unlocks left until Monday.")
        }
        .onDisappear { stopTicking() }
    }

    private var holdBox: some View {
        ZStack {
            Rectangle()
                .strokeBorder(Theme.glow, lineWidth: 3)
            TimelineView(.periodic(from: .now, by: 0.05)) { context in
                let elapsed = elapsedSeconds(at: context.date)
                VStack(spacing: 14) {
                    Text("\(max(0, Int((holdSeconds - elapsed).rounded(.up))))")
                        .font(Theme.lcdFont(64))
                        .monospacedDigit()
                        .shadow(color: Theme.glow.opacity(0.55), radius: 10)
                    HStack(spacing: 6) {
                        ForEach(0..<5, id: \.self) { index in
                            Rectangle()
                                .fill(elapsed >= Double(index + 1) ? Theme.glow : Color.clear)
                                .frame(width: 22, height: 14)
                                .overlay(Rectangle().strokeBorder(Theme.glow, lineWidth: 1))
                        }
                    }
                }
            }
        }
        .frame(width: 190, height: 190)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: holdSeconds, maximumDistance: 60) {
            stopTicking()
            pressStart = nil
            confirming = true
        } onPressingChanged: { pressing in
            if pressing {
                pressStart = .now
                startTicking()
            } else {
                let held = pressStart.map { Date.now.timeIntervalSince($0) } ?? 0
                stopTicking()
                pressStart = nil
                if held < holdSeconds - 0.1 { cancelCount += 1 }
            }
        }
    }

    private func elapsedSeconds(at date: Date) -> Double {
        guard let pressStart else { return 0 }
        return min(holdSeconds, max(0, date.timeIntervalSince(pressStart)))
    }

    /// One light tick a second while holding.
    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                ticks += 1
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }
}
