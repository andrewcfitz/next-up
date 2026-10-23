import SwiftUI

extension StayBreak.Kind {
    var systemImage: String {
        switch self {
        case .gap: "exclamationmark.triangle.fill"
        case .overlap: "square.on.square"
        }
    }

    /// Darker than the system red and green in light mode, so the text on a tinted row stays readable.
    var color: Color {
        switch self {
        case .gap: Color(light: 0xC62828, dark: 0xFF453A)
        case .overlap: Color(light: 0x2E7D32, dark: 0x30D158)
        }
    }
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        #if os(watchOS)
        self.init(rgb: dark)
        #elseif canImport(UIKit)
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(rgb: dark)) : UIColor(Color(rgb: light)) })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? NSColor(Color(rgb: dark)) : NSColor(Color(rgb: light))
        })
        #endif
    }

    init(rgb: UInt32) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }
}
