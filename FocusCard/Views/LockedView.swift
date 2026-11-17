import SwiftUI

/// Locked: only the lock, a count-up timer, and the ways out.
struct LockedView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmEmergency = false
    @State private var showRecovery = false

    var body: some View {
        VStack(spacing: 0) {
            if let lock = model.lock {
                Label(lock.modeName.uppercased(), systemImage: "lock.fill")
                    .font(.footnote.weight(.semibold))
                    .tracking(0.6)
                    .labelStyle(TintedIconLabelStyle())
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .padding(.top, 24)

                Spacer()

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = max(0, context.date.timeIntervalSince(lock.since))
                    ZStack {
                        Circle()
                            .stroke(Color(.systemFill), lineWidth: 5)
                        // Fills once an hour, then starts again.
                        Circle()
                            .trim(from: 0, to: elapsed.truncatingRemainder(dividingBy: 3600) / 3600)
                            .stroke(.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 8) {
                            Text(Self.elapsed(elapsed))
                                .font(.system(size: 68, weight: .thin))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            if let releaseAt = lock.releaseAt {
                                Text("Unlocks in \(Self.elapsed(max(0, releaseAt.timeIntervalSince(context.date))))")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            } else {
                                Text("Focused")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 280, height: 280)
                }

                Spacer()
            }

            VStack(spacing: HomeView.spacing) {
                if model.lock?.releaseAt != nil {
                    Button("Cancel 24-Hour Wait") { model.cancelWait() }
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 44)
                }
                Button {
                    Task { await model.scanToToggle() }
                } label: {
                    Label("Tap Card to Unlock", systemImage: "wave.3.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)

                EmergencyHoldButton(remaining: model.emergency.remaining) {
                    confirmEmergency = true
                }

                Button("Lost your card?") { showRecovery = true }
                    .font(.subheadline.weight(.medium))
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .alert("Use an emergency unlock?", isPresented: $confirmEmergency) {
            Button("Unlock", role: .destructive) { model.emergencyUnlock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            let left = max(0, model.emergency.remaining - 1)
            Text("\(model.lock?.modeName ?? "Work") unlocks now. You will have \(left) of \(model.emergency.perWeek) left this week. They reset on Monday.")
        }
        // Ends the 24-hour wait on time while the app is open.
        .task(id: model.lock?.releaseAt) {
            guard let releaseAt = model.lock?.releaseAt else { return }
            let delay = releaseAt.timeIntervalSinceNow
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            if !Task.isCancelled { model.reload() }
        }
        .sheet(isPresented: $showRecovery) {
            RecoveryUnlockView()
                .presentationDetents([.medium])
        }
    }

    /// "1:24:08", or "4:08" under an hour.
    static func elapsed(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// Green lock icon beside the mode name.
private struct TintedIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.foregroundStyle(.green)
            configuration.title
        }
    }
}

/// Press and hold for 5 seconds. A red fill shows progress; letting go early cancels.
struct EmergencyHoldButton: View {
    let remaining: Int
    let onComplete: () -> Void
    @State private var pressing = false

    var body: some View {
        Text(remaining > 0 ? "Hold for Emergency Unlock · \(remaining) left" : "No emergency unlocks left until Monday")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(remaining > 0 ? Color.red : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(alignment: .leading) {
                GeometryReader { proxy in
                    Rectangle()
                        .fill(.red.opacity(0.2))
                        .frame(width: pressing ? proxy.size.width : 0)
                        .animation(pressing ? .linear(duration: 5) : .easeOut(duration: 0.2), value: pressing)
                }
            }
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onLongPressGesture(minimumDuration: 5, maximumDistance: 40) {
                pressing = false
                onComplete()
            } onPressingChanged: { isPressing in
                pressing = isPressing && remaining > 0
            }
            .disabled(remaining == 0)
            .sensoryFeedback(.warning, trigger: pressing) { _, new in new }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(remaining > 0 ? "Emergency unlock, \(remaining) left. Press and hold for 5 seconds." : "No emergency unlocks left until Monday")
            .accessibilityAction { if remaining > 0 { onComplete() } }
    }
}

/// Unlocks with the recovery password. Doesn't use an emergency unlock.
struct RecoveryUnlockView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var entered = ""
    @State private var wrong = false
    @State private var attempts = 0
    @State private var confirmWait = false

    var body: some View {
        VStack(spacing: HomeView.spacing) {
            Text("Recovery Password").font(.title3.weight(.semibold))
            Text("Use this if your card is lost or will not scan. It does not use an emergency unlock.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // .password lets iOS offer the code saved in Passwords.
            TextField("FC-XXXX-XXXX", text: $entered)
                .textContentType(.password)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .multilineTextAlignment(.center)
                .frame(height: 54)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 14))
                .modifier(Shake(amount: CGFloat(attempts)))
                .onSubmit(tryUnlock)
            Text(wrong ? "Incorrect password" : " ")
                .font(.footnote)
                .foregroundStyle(.red)
            Button(action: tryUnlock) {
                Text("Unlock").font(.headline).frame(maxWidth: .infinity).frame(height: 54)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            if model.lock?.releaseAt == nil {
                Button("Forgot your password?") { confirmWait = true }
                    .font(.subheadline)
            }
            Button("Cancel") { dismiss() }
        }
        .padding(24)
        .sensoryFeedback(.error, trigger: attempts)
        .confirmationDialog("Wait 24 hours?", isPresented: $confirmWait, titleVisibility: .visible) {
            Button("Start 24-Hour Wait", role: .destructive) {
                Task { await model.startWait() }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your apps unlock by themselves in 24 hours. Your card or password still unlocks sooner. This does not use an emergency unlock.")
        }
    }

    private func tryUnlock() {
        if model.unlockWithRecovery(entered) {
            dismiss()
        } else {
            wrong = true
            withAnimation(.default) { attempts += 1 }
        }
    }
}

/// Side-to-side shake for a wrong entry.
struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 4), y: 0))
    }
}
