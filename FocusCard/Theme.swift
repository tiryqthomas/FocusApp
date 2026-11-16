import SwiftUI
import UIKit

/// The Y2K handset look: a light or dark LCD with a blue title bar, square
/// bevelled buttons, and pale-blue monospaced text on the black locked screens.
/// Light and dark follow the system unless Settings overrides them.
enum Theme {
    static let blue = adaptive(light: 0x2F5FB3, dark: 0x3B72D0)
    static let blueHigh = Color(UIColor(hex: 0x4A7BD0))
    static let blueLow = Color(UIColor(hex: 0x2A4F9E))
    static let blueInk = Color(UIColor(hex: 0x1B3A78))

    /// Pale blue on the black locked screens.
    static let glow = Color(UIColor(hex: 0x9EC1FF))
    static let glowHigh = Color(UIColor(hex: 0xD6E4FF))

    static let lcd = adaptive(light: 0xF4F5F7, dark: 0x14171C)
    static let panel = adaptive(light: 0xFFFFFF, dark: 0x1D2129)
    static let bar = adaptive(light: 0xE6E8EC, dark: 0x0D0F13)
    static let line = adaptive(light: 0xC9CCD2, dark: 0x2C313B)
    static let edge = adaptive(light: 0x9EA2A9, dark: 0x3F4652)
    static let buttonTop = adaptive(light: 0xFDFDFD, dark: 0x3A414D)
    static let buttonBottom = adaptive(light: 0xCFD3DA, dark: 0x262B34)
    static let buttonLine = adaptive(light: 0x6E737C, dark: 0x4A5260)
    static let danger = adaptive(light: 0xB3372E, dark: 0xFF7A6E)

    static let titleGradient = LinearGradient(colors: [blueHigh, blueLow], startPoint: .top, endPoint: .bottom)
    static let buttonGradient = LinearGradient(colors: [buttonTop, buttonBottom], startPoint: .top, endPoint: .bottom)

    /// The monospaced face used for the LCD text. Bundle VT323 later for the exact pixel look.
    static func lcdFont(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private func adaptive(light: UInt, dark: UInt) -> Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
    })
}

// MARK: Haptics

/// A haptic that Settings can switch off.
struct HapticModifier<Trigger: Equatable>: ViewModifier {
    @AppStorage("haptics") private var enabled = true
    private let feedback: SensoryFeedback
    private let trigger: Trigger
    private let condition: (Trigger, Trigger) -> Bool

    init(feedback: SensoryFeedback, trigger: Trigger, condition: @escaping (Trigger, Trigger) -> Bool) {
        self.feedback = feedback
        self.trigger = trigger
        self.condition = condition
    }

    func body(content: Content) -> some View {
        content.sensoryFeedback(feedback, trigger: trigger) { old, new in
            enabled && condition(old, new)
        }
    }
}

extension View {
    func haptic<Trigger: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: Trigger,
        when condition: @escaping (Trigger, Trigger) -> Bool = { _, _ in true }
    ) -> some View {
        modifier(HapticModifier(feedback: feedback, trigger: trigger, condition: condition))
    }

    /// A flat panel with a thin square border, like a list on an old handset.
    func lcdPanel() -> some View {
        background(Theme.panel)
            .overlay(Rectangle().strokeBorder(Theme.edge, lineWidth: 1))
    }

    func lcdScreen() -> some View {
        background(Theme.lcd.ignoresSafeArea())
    }

    /// A Form or List on the LCD background with the blue title bar.
    func lcdForm() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.lcd.ignoresSafeArea())
            .lcdNavigationBar()
    }

    /// The blue gradient title bar.
    func lcdNavigationBar() -> some View {
        toolbarBackground(Theme.titleGradient, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// The black locked screens: pale-blue monospaced text over scanlines.
    func blackScreen() -> some View {
        foregroundStyle(Theme.glow)
            .background(Color.black.ignoresSafeArea())
            .overlay { Scanlines() }
            .environment(\.colorScheme, .dark)
    }
}

// MARK: Buttons

/// The main action on a screen: a blue bevelled button.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Theme.titleGradient)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.blueInk, lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .haptic(.impact(weight: .medium), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

/// A grey bevelled button for secondary actions.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Theme.buttonGradient)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.buttonLine, lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .haptic(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

/// Buttons on the black screens: filled pale blue, or just an outline.
struct GlowButtonStyle: ButtonStyle {
    var filled = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.lcdFont(filled ? 24 : 20))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(filled ? Color.black : Theme.glow)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: filled ? 56 : 46)
            .background(filled ? Theme.glow : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(filled ? Theme.glowHigh : Theme.glow, lineWidth: 2))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .haptic(.impact(weight: .medium), trigger: configuration.isPressed) { _, pressed in pressed }
    }
}

// MARK: Pieces

/// Faint horizontal lines over the black screens, like an old LCD.
struct Scanlines: View {
    var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(.black.opacity(0.28)))
                y += 3
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A square segmented control, such as Day, Week and Month.
struct LCDSegment<Option: Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    @Binding var selection: Option

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.spring(duration: 0.25)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(isSelected ? AnyShapeStyle(Theme.blue) : AnyShapeStyle(Theme.buttonGradient))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .overlay(Rectangle().strokeBorder(Theme.buttonLine, lineWidth: 1))
        .haptic(.selection, trigger: selection)
    }
}
