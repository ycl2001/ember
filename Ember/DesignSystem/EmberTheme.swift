import SwiftUI

/// Ember's light, sage-and-amber palette, adapted from the supplied HTML screens.
enum EmberTheme {
    static let primary = Color(red: 9/255, green: 34/255, blue: 25/255)
    static let surface = Color(red: 255/255, green: 253/255, blue: 251/255)
    static let mint = Color(red: 212/255, green: 235/255, blue: 218/255)
    static let amber = Color(red: 233/255, green: 172/255, blue: 107/255)
    static let muted = Color(red: 83/255, green: 100/255, blue: 90/255)
    static let separator = Color(red: 220/255, green: 226/255, blue: 216/255)

    static var canvas: some View {
        Image("PaperGrain")
            .resizable(resizingMode: .tile)
            .background(Color(red: 243/255, green: 240/255, blue: 232/255))
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}
