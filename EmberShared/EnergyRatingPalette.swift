import SwiftUI

enum EnergyRatingPalette {
    static func color(for level: Int?) -> Color? {
        switch level {
        case 1: Color(.sRGB, red: 0xE3 / 255, green: 0x5D / 255, blue: 0x5E / 255)
        case 2: Color(.sRGB, red: 0xF1 / 255, green: 0x9C / 255, blue: 0x4A / 255)
        case 3: Color(.sRGB, red: 0x93 / 255, green: 0x63 / 255, blue: 0x3D / 255)
        case 4: Color(.sRGB, red: 0x4A / 255, green: 0x8F / 255, blue: 0xCA / 255)
        case 5: Color(.sRGB, red: 0x4A / 255, green: 0xA1 / 255, blue: 0x6D / 255)
        default: nil
        }
    }

    static func labelColor(on level: Int) -> Color {
        level == 3 ? .white : .black
    }
}
