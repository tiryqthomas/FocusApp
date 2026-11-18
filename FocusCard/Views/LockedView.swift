import SwiftUI

/// The whole app turns black while locked. Before wake time it says good night and the
/// card does nothing; after, it asks you to get up and tap the card.
/// It powers on like an old LCD, with a timer, an emergency unlock, and a way
/// back in if the card is lost.
struct LockedView: View {
    @Environment(AppModel.self) private var model
    @State private var showEmergency = false
    @State private var showLost = false
    @State private var powered = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                content(now: context.date)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            // Power-on: the screen opens from a bright line.
            .scaleEffect(x: powered ? 1 : 0.6, y: powered ? 1 : 0.02)
            .brightness(powered ? 0 : 1)
            .blackScreen()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showEmergency) {
                EmergencyUnlockView()
            }
            .navigationDestination(isPresented: $showLost) {
                LostCardView()
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { powered = true }
        }
        // A 24-hour recovery wait unlocks by itself when it runs out.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                model.finishRecoveryWaitIfDue()
            }
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let held = model.cardIsHeld(at: now)
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: held ? "moon.fill" : "lock.fill")
                .font(.system(size: 64))
            if let lock = model.lock {
                if held, let wake = lock.wakeAt {
                    Text("GOOD NIGHT")
                        .font(Theme.lcdFont(26))
                        .tracking(2)
                    Text("UNLOCKS WITH YOUR CARD AFTER \(wake.formatted(date: .omitted, time: .shortened).uppercased())")
                        .font(Theme.lcdFont(16))
                        .multilineTextAlignment(.center)
                        .opacity(0.8)
                    Text(Self.countdown(to: wake, now: now))
                        .font(Theme.lcdFont(56))
                        .monospacedDigit()
                        .shadow(color: Theme.glow.opacity(0.55), radius: 12)
                    Text("UNTIL WAKE TIME")
                        .font(Theme.lcdFont(14))
                        .opacity(0.7)
                } else if lock.night == true {
                    Text("GOOD MORNING")
                        .font(Theme.lcdFont(26))
                        .tracking(2)
                    Text("GET UP AND TAP YOUR CARD")
                        .font(Theme.lcdFont(18))
                        .opacity(0.9)
                } else {
                    Text("LOCKED")
                        .font(Theme.lcdFont(22))
                        .tracking(2)
                    Text(Self.elapsed(from: lock.since, to: now))
                        .font(Theme.lcdFont(64))
                        .monospacedDigit()
                        .shadow(color: Theme.glow.opacity(0.55), radius: 12)
                }
            }
            if let end = model.recoveryWaitEnd {
                Text("RECOVERY WAIT: \(Self.countdown(to: end, now: now))")
                    .font(Theme.lcdFont(16))
                    .opacity(0.9)
            }
            Spacer()
            VStack(spacing: 10) {
                if held {
                    Text("YOUR CARD DOES NOTHING BEFORE WAKE TIME.")
                        .font(Theme.lcdFont(13))
                        .multilineTextAlignment(.center)
                        .opacity(0.7)
                } else {
                    Button {
                        Task { await model.unlockWithCard() }
                    } label: {
                        Text("UNLOCK WITH CARD")
                    }
                    .buttonStyle(GlowButtonStyle())
                }

                Button {
                    showEmergency = true
                } label: {
                    Text("EMERGENCY UNLOCK · \(model.emergencyLeft) LEFT THIS WEEK")
                }
                .buttonStyle(GlowButtonStyle(filled: false))
                .disabled(model.emergencyLeft == 0)

                Button("I LOST MY CARD") { showLost = true }
                    .font(Theme.lcdFont(17))
                    .underline()
                    .frame(height: 36)
            }
        }
    }

    /// "1:24:08"
    static func elapsed(from start: Date, to now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// "23:59:58"
    static func countdown(to end: Date, now: Date) -> String {
        let total = max(0, Int(end.timeIntervalSince(now).rounded(.up)))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
