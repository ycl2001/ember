import SwiftUI

/// Persistent bottom navigation for the four primary sections.
/// Detail flows are pushed over the tab root, so they don't duplicate this bar.
struct EmberTabBar: View {
    let selected: AppTab
    let onSelect: (AppTab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: selected == tab ? tab.selectedSymbol : tab.symbol)
                            .font(.system(size: 19, weight: .medium))
                            .frame(height: 24)
                        Text(tab.title)
                            .font(.system(size: 11, weight: selected == tab ? .semibold : .medium))
                    }
                    .foregroundStyle(selected == tab ? EmberTheme.primary : EmberTheme.muted)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .padding(.vertical, 4)
                    .background {
                        if selected == tab {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(EmberTheme.mint.opacity(0.75))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("tab_\(tab.rawValue)")
                .accessibilityAddTraits(selected == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 5)
        .background {
            EmberTheme.surface
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle().fill(EmberTheme.separator).frame(height: 1)
                }
        }
    }
}
