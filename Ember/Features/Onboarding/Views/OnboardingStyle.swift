import SwiftUI

/// Colours and small shared components for the onboarding and energy check-in screens.
/// If the shared DesignSystem already has equivalents, swap these for those tokens.
enum FlowPalette {
    static let background = Color(red: 0.980, green: 0.973, blue: 0.961)
    static let card = Color.white
    static let surface = Color(red: 0.953, green: 0.945, blue: 0.925)
    static let chip = Color(red: 0.918, green: 0.910, blue: 0.890)
    static let track = Color(red: 0.90, green: 0.89, blue: 0.87)
    static let ink = Color(red: 0.07, green: 0.10, blue: 0.09)
    static let secondaryInk = Color(red: 0.36, green: 0.39, blue: 0.37)
    static let forest = Color(red: 0.07, green: 0.19, blue: 0.16)
    static let deep = Color(red: 0.02, green: 0.12, blue: 0.10)
    static let mint = Color(red: 0.745, green: 0.937, blue: 0.839)
    static let mintText = Color(red: 0.05, green: 0.35, blue: 0.24)
    static let peach = Color(red: 1.0, green: 0.85, blue: 0.74)
    static let brown = Color(red: 0.54, green: 0.29, blue: 0.05)
    static let orange = Color(red: 1.0, green: 0.57, blue: 0.16)
    static let red = Color(red: 0.70, green: 0.15, blue: 0.12)
    static let redSoft = Color(red: 0.99, green: 0.85, blue: 0.85)
}

// MARK: - Text

struct FlowTitle: View {
    let title: String
    var subtitle: String? = nil
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(compact ? .title2 : .title, design: .serif, weight: .semibold))
                .foregroundStyle(FlowPalette.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(FlowPalette.secondaryInk)
            }
        }
    }
}

struct FlowHeading: View {
    let title: String
    var systemImage: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(FlowPalette.brown)
            }
            Text(title)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(FlowPalette.ink)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.footnote)
                    .foregroundStyle(FlowPalette.secondaryInk)
            }
        }
    }
}

struct FlowSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(FlowPalette.secondaryInk)
    }
}

// MARK: - Cards

extension View {
    /// White card with a soft shadow.
    func flowCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FlowPalette.card, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
    }

    /// Selected cards are white with a shadow, unselected cards are flat grey.
    func flowSelectable(selected: Bool) -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? FlowPalette.card : FlowPalette.surface,
                        in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(selected ? 0.06 : 0), radius: 6, y: 2)
    }
}

// MARK: - Controls

struct FlowPill: View {
    let text: String
    var background: Color = FlowPalette.chip
    var foreground: Color = FlowPalette.secondaryInk
    var systemImage: String? = nil
    var showsDot = false

    var body: some View {
        HStack(spacing: 5) {
            if showsDot {
                Circle().fill(foreground).frame(width: 6, height: 6)
            }
            if let systemImage {
                Image(systemName: systemImage).font(.caption2)
            }
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .foregroundStyle(foreground)
        .background(background, in: Capsule())
    }
}

struct FlowCheck: View {
    let isSelected: Bool
    var isRadio = false
    var onDark = false

    var body: some View {
        ZStack {
            if isSelected {
                Circle().fill(onDark ? Color(red: 0.20, green: 0.62, blue: 0.42) : FlowPalette.forest)
                if isRadio {
                    Circle().fill(Color.white).frame(width: 8, height: 8)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            } else {
                Circle().fill(onDark ? Color.white.opacity(0.15) : FlowPalette.chip)
            }
        }
        .frame(width: 28, height: 28)
    }
}

/// Small grey rounded tag, used for topic suggestions. Turns dark green when selected.
struct FlowTag: View {
    let title: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? Color.white : FlowPalette.secondaryInk)
                .background(isSelected ? FlowPalette.forest : FlowPalette.chip,
                            in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Capsule chip with an optional icon and tag. Dark green when selected.
struct FlowChip: View {
    let title: String
    var systemImage: String? = nil
    var tag: String? = nil
    var tagTint: Color = FlowPalette.mint
    var showsCheck = false
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage).font(.footnote)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.leading)
                if let tag {
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(isSelected ? tagTint : FlowPalette.secondaryInk)
                        .background(isSelected ? Color.white.opacity(0.12) : FlowPalette.chip,
                                    in: Capsule())
                }
                if showsCheck && isSelected {
                    Image(systemName: "checkmark").font(.caption.weight(.bold))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? Color.white : FlowPalette.ink)
            .background(isSelected ? FlowPalette.forest : FlowPalette.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct FlowPrimaryButtonStyle: ButtonStyle {
    var fill: Color = FlowPalette.forest
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(fill.opacity(isEnabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 14))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct FlowButtonLabel: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            if let systemImage {
                Image(systemName: systemImage)
            }
        }
    }
}

// MARK: - Layout

/// Simple wrapping row layout for chips and tags.
struct WrappingLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }
        return CGSize(width: usedWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Header and progress

/// Decorative profile avatar from the design. Not interactive.
struct FlowAvatar: View {
    var body: some View {
        Image(systemName: "person")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: 40, height: 40)
            .background(FlowPalette.forest, in: Circle())
            .accessibilityHidden(true)
    }
}

struct FlowTopBar: View {
    let title: String
    var leadingSymbol: String = "arrow.left"
    var showsClose = true
    var showsAvatar = true
    var centersTitle = false
    let onLeading: () -> Void
    var onClose: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onLeading) {
                Image(systemName: leadingSymbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel(leadingSymbol == "arrow.left" ? "Back" : "Close")

            if centersTitle {
                Spacer(minLength: 0)
            }

            Text(title)
                .font(.system(.title3, design: .serif, weight: .semibold))

            Spacer(minLength: 0)

            if showsClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Close")
            }

            if showsAvatar {
                FlowAvatar()
            }
        }
        .foregroundStyle(FlowPalette.ink)
        .buttonStyle(.plain)
    }
}

struct FlowProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(FlowPalette.track)
                Capsule()
                    .fill(FlowPalette.forest)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 5)
    }
}
