import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32) { self.init(UIColor(hex: hex)) }

    static func sbDynamic(dark: UInt32, light: UInt32) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// Дизайн-система SOBATOVSKY OS: палитра, отступы, шрифты.
enum SB {
    static let background = Color.sbDynamic(dark: 0x09090B, light: 0xF4F4F5)   // Obsidian Black
    static let deep       = Color.sbDynamic(dark: 0x111114, light: 0xEBEBED)   // Deep Graphite
    static let surface    = Color.sbDynamic(dark: 0x18181B, light: 0xFFFFFF)   // Graphite Surface
    static let elevated   = Color.sbDynamic(dark: 0x202024, light: 0xEFEFF1)   // Elevated Surface
    static let border     = Color.sbDynamic(dark: 0x2B2B31, light: 0xDADADF)   // Border Gray
    static let muted      = Color.sbDynamic(dark: 0x71717A, light: 0x8A8A93)   // Muted Silver
    static let silver     = Color.sbDynamic(dark: 0xA1A1AA, light: 0x5C5C66)   // Silver
    static let platinum   = Color.sbDynamic(dark: 0xE4E4E7, light: 0x27272A)   // Platinum
    static let white      = Color.sbDynamic(dark: 0xFAFAFA, light: 0x09090B)   // Pure White

    static let success = Color.sbDynamic(dark: 0x4ADE80, light: 0x16A34A)
    static let warning = Color.sbDynamic(dark: 0xFBBF24, light: 0xB45309)
    static let error   = Color.sbDynamic(dark: 0xF87171, light: 0xDC2626)
    static let info    = Color.sbDynamic(dark: 0x60A5FA, light: 0x2563EB)
    static let violet  = Color.sbDynamic(dark: 0xA78BFA, light: 0x7C3AED)

    static let primaryFill = Color.sbDynamic(dark: 0xE4E4E7, light: 0x18181B)
    static let primaryText = Color.sbDynamic(dark: 0x09090B, light: 0xFAFAFA)

    static let subjectPalette: [Color] = [
        Color(hex: 0xA1A1AA), Color(hex: 0x60A5FA), Color(hex: 0xA78BFA),
        Color(hex: 0x4ADE80), Color(hex: 0xFBBF24), Color(hex: 0xF87171), Color(hex: 0x94A3B8)
    ]
    static func subjectColor(_ index: Int) -> Color {
        subjectPalette[((index % subjectPalette.count) + subjectPalette.count) % subjectPalette.count]
    }

    static let pad: CGFloat = 20
}

extension Font {
    static func sb(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

/// Глобальные переключатели анимаций и тактильной отдачи (обновляются из настроек).
enum SBMotion {
    static var enabled = true
    static var anim: Animation? {
        (enabled && !UIAccessibility.isReduceMotionEnabled) ? .easeOut(duration: 0.25) : nil
    }
}

enum Haptics {
    static var enabled = true
    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
