import SwiftUI

/// Canvas screen 4: the whole app turns black while locked (Decision 9).
/// It powers on like an old LCD, with a timer, an emergency unlock, and a way
/// back in if the card is lost.
struct LockedView: View {
    @Environment(AppModel.self) private var model
    @State private var showEmergency = false
    @State private var showLost = false
    @State private var powered = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.system(size: 64))
                if let lock = model.lock {
                    Text("\(lock.modeName.uppercased()) IS LOCKED")
                        .font(Theme.lcdFont(22))
                        .tracking(2)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Self.elapsed(from: lock.since, to: context.date))
                            .font(Theme.lcdFont(64))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .shadow(color: Theme.glow.opacity(0.55), radius: 12)
                    }
                }
                if let mode = model.lockedMode {
                    Text("\(mode.selectionSummary.uppercased()) BLOCKED")
                        .font(Theme.lcdFont(16))
                        .opacity(0.8)
                }
                if let end = model.recoveryWaitEnd {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("RECOVERY WAIT: \(Self.countdown(to: end, now: context.date))")
                            .font(Theme.lcdFont(16))
                            .opacity(0.9)
                    }
                }
                Spacer()
                VStack(spacing: 10) {
                    Button {
                        Task { await model.unlockWithCard() }
                    } label: {
                        Text("UNLOCK WITH CARD")
                    }
                    .buttonStyle(GlowButtonStyle())

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
