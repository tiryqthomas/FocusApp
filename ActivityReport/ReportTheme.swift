import SwiftUI
import UIKit

/// The report extension can't see the app's Theme, so these are the same colours again.
enum ReportTheme {
    static let blue = adaptive(light: 0x2F5FB3, dark: 0x3B72D0)
    static let panel = adaptive(light: 0xFFFFFF, dark: 0x1D2129)
    static let edge = adaptive(light: 0x9EA2A9, dark: 0x3F4652)

    private static func adaptive(light: UInt, dark: UInt) -> Color {
        func color(_ hex: UInt) -> UIColor {
            UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? color(dark) : color(light) })
    }
}

extension View {
    /// A flat panel with a thin square border, matching the app's lcdPanel.
    func reportPanel() -> some View {
        background(ReportTheme.panel)
            .overlay(Rectangle().strokeBorder(ReportTheme.edge, lineWidth: 1))
    }
}
