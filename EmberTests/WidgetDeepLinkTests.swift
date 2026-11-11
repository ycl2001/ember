import Foundation
import Testing
@testable import Ember

@MainActor
struct WidgetDeepLinkTests {
    @Test
    func focusWidgetURLRoutesOnceToFocus() throws {
        let navigation = AppNavigation()
        let url = try #require(URL(string: "ember://focus"))

        #expect(navigation.handleWidgetURL(url))
        #expect(navigation.path == [.focus])

        #expect(navigation.handleWidgetURL(url))
        #expect(navigation.path == [.focus])
    }

    @Test
    func monthlyWidgetURLSelectsMonthlyAnalytics() throws {
        let navigation = AppNavigation()
        navigation.path = [.focus]
        let url = try #require(URL(string: "ember://analytics/monthly"))

        #expect(navigation.handleWidgetURL(url))
        #expect(navigation.selectedTab == .analytics)
        #expect(navigation.analyticsPeriod == .monthly)
        #expect(navigation.path.isEmpty)
    }

    @Test
    func unrelatedURLsDoNotChangeNavigation() throws {
        let navigation = AppNavigation()
        let url = try #require(URL(string: "https://example.com/analytics/monthly"))

        #expect(!navigation.handleWidgetURL(url))
        #expect(navigation.selectedTab == .today)
        #expect(navigation.path.isEmpty)
    }
}
