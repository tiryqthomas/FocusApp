import SwiftUI

/// One spacing grid and a few shared pieces, so every screen lines up.
enum Theme {
    /// Screen edges and the gap between blocks.
    static let spacing: CGFloat = 16
    /// Gap inside a group (a label and its content, pills in a row).
    static let groupSpacing: CGFloat = 8
    /// Height of a label and value row.
    static let rowHeight: CGFloat = 48
    /// Padding inside a card.
    static let cardPadding: CGFloat = 16
    static let cardRadius: CGFloat = 22
    /// Main buttons (Lock, Tap Card to Unlock).
    static let primaryButtonHeight: CGFloat = 58
    /// Secondary buttons and pills.
    static let pillHeight: CGFloat = 44

    static let focus = Color.green
    static let screen = Color.blue
    static let pickups = Color.orange
}

/// "FOCUS MODE": small, spaced capitals above a block.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// A grouped card with a hairline edge.
    func card(padding: CGFloat = Theme.cardPadding) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }

    /// Haptic feedback that follows the Haptics switch in Settings.
    func haptic<T: Equatable>(_ feedback: SensoryFeedback, enabled: Bool, trigger: T) -> some View {
        sensoryFeedback(feedback, trigger: trigger) { _, _ in enabled }
    }
}

/// A full-width capsule button with a solid fill.
struct CapsuleButtonStyle: ButtonStyle {
    var fill: Color
    var text: Color
    var height: CGFloat = Theme.primaryButtonHeight

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

/// A ring that fills to `progress` (0 to 1) with a value in the middle.
struct StatRing: View {
    let progress: Double
    let color: Color
    let value: String
    let label: String
    var size: CGFloat = 104
    var lineWidth: CGFloat = 10

    var body: some View {
        VStack(spacing: Theme.groupSpacing) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: min(1, max(0, progress)))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(value)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .frame(width: size, height: size)
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}
