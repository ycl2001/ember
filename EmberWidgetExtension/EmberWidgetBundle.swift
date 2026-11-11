import WidgetKit
import SwiftUI

@main
struct EmberWidgetBundle: WidgetBundle {
    var body: some Widget {
        EmberFocusWidget()
        MonthlyEnergyWidget()
    }
}
