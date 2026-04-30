import SwiftUI

enum CodexTheme {
    static let accent = Color(nsColor: dynamic(
        light: NSColor(calibratedRed: 0.95, green: 0.33, blue: 0.09, alpha: 1),
        dark: NSColor(calibratedRed: 1.00, green: 0.48, blue: 0.22, alpha: 1)
    ))
    static let statusGreen = Color(nsColor: dynamic(
        light: NSColor(calibratedRed: 0.20, green: 0.74, blue: 0.35, alpha: 1),
        dark: NSColor(calibratedRed: 0.27, green: 0.82, blue: 0.44, alpha: 1)
    ))
    static let panelBackground = Color(nsColor: dynamic(
        light: NSColor(calibratedRed: 0.965, green: 0.936, blue: 0.850, alpha: 1),
        dark: NSColor(calibratedRed: 0.165, green: 0.188, blue: 0.205, alpha: 1)
    ))
    static let contentBackground = Color(nsColor: dynamic(
        light: NSColor(calibratedRed: 0.985, green: 0.968, blue: 0.920, alpha: 1),
        dark: NSColor(calibratedRed: 0.125, green: 0.145, blue: 0.160, alpha: 1)
    ))
    static let cardBackground = Color(nsColor: dynamic(
        light: NSColor(calibratedRed: 0.925, green: 0.900, blue: 0.830, alpha: 0.72),
        dark: NSColor(calibratedRed: 0.215, green: 0.238, blue: 0.255, alpha: 0.82)
    ))
    static let controlBackground = Color(nsColor: dynamic(
        light: NSColor(calibratedRed: 0.885, green: 0.865, blue: 0.805, alpha: 0.90),
        dark: NSColor(calibratedRed: 0.255, green: 0.280, blue: 0.300, alpha: 0.90)
    ))
    static let primaryText = Color(nsColor: dynamic(
        light: NSColor(calibratedRed: 0.19, green: 0.22, blue: 0.24, alpha: 1),
        dark: NSColor(calibratedRed: 0.88, green: 0.86, blue: 0.80, alpha: 1)
    ))
    static let secondaryText = Color(nsColor: dynamic(
        light: NSColor(calibratedRed: 0.43, green: 0.49, blue: 0.52, alpha: 1),
        dark: NSColor(calibratedRed: 0.66, green: 0.69, blue: 0.68, alpha: 1)
    ))
    static let divider = Color(nsColor: dynamic(
        light: NSColor(calibratedRed: 0.82, green: 0.79, blue: 0.71, alpha: 0.55),
        dark: NSColor(calibratedRed: 0.30, green: 0.33, blue: 0.35, alpha: 0.65)
    ))

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            let best = appearance.bestMatch(from: [.darkAqua, .aqua])
            return best == .darkAqua ? dark : light
        }
    }
}
