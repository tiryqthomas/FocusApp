import SwiftUI

/// Canvas: "I lost my card". Two ways back in, and neither uses an emergency unlock:
/// the recovery code made at setup, or a 24-hour wait.
struct LostCardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var code = ""
    @State private var wrongCount = 0
    @State private var warn = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("I LOST MY CARD")
                    .font(Theme.lcdFont(26))
                    .tracking(2)
                Text("This does not use an emergency unlock.")
                    .font(Theme.lcdFont(16))
                    .opacity(0.8)

                VStack(alignment: .leading, spacing: 10) {
                    Text("1. RECOVERY CODE")
                        .font(Theme.lcdFont(18))
                    TextField("", text: $code, prompt: Text("FC-XXXX-XXXX").foregroundStyle(Theme.glow.opacity(0.4)))
                        .font(Theme.lcdFont(24))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(12)
                        .overlay(Rectangle().strokeBorder(Theme.glow, lineWidth: 2))
                        .phaseAnimator([0.0, -8.0, 8.0, -5.0, 5.0, 0.0], trigger: wrongCount) { view, offset in
                            view.offset(x: reduceMotion ? 0 : offset)
                        } animation: { _ in .linear(duration: 0.06) }
                    Button("UNLOCK") {
                        if !model.unlockWithRecoveryCode(code) {
                            wrongCount += 1
                            warn += 1
                        }
                    }
                    .buttonStyle(GlowButtonStyle())
                    .disabled(code.isEmpty)
                    if wrongCount > 0 {
                        Text("THAT CODE DOES NOT MATCH.")
                            .font(Theme.lcdFont(14))
                            .foregroundStyle(Theme.danger)
                    }
                }
                .sensoryFeedback(.warning, trigger: warn)

                Rectangle().fill(Theme.glow.opacity(0.3)).frame(height: 1)

                VStack(alignment: .leading, spacing: 10) {
                    Text("2. WAIT 24 HOURS")
                        .font(Theme.lcdFont(18))
                    if let end = model.recoveryWaitEnd {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(LockedView.countdown(to: end, now: context.date))
                                .font(Theme.lcdFont(48))
                                .monospacedDigit()
                                .shadow(color: Theme.glow.opacity(0.55), radius: 10)
                        }
                        Text("IT UNLOCKS BY ITSELF WHEN THIS REACHES ZERO.")
                            .font(Theme.lcdFont(14))
                            .opacity(0.8)
                        Button("CANCEL WAIT") { model.cancelRecoveryWait() }
                            .buttonStyle(GlowButtonStyle(filled: false))
                    } else {
                        Text("START A TIMER. THE MODE UNLOCKS WHEN IT ENDS.")
                            .font(Theme.lcdFont(14))
                            .opacity(0.8)
                        Button("START 24 HOUR WAIT") { model.startRecoveryWait() }
                            .buttonStyle(GlowButtonStyle(filled: false))
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .blackScreen()
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
