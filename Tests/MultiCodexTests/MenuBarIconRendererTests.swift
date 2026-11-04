import XCTest
@testable import MultiCodex

final class MenuBarIconRendererTests: XCTestCase {
    func testRenderedIconUsesMenuBarTemplateSize() {
        let image = MenuBarIconRenderer.render(
            fiveHourProgress: 0.58,
            weeklyProgress: 0.83,
            fiveHourUsedPercent: 42,
            weeklyUsedPercent: 17,
            isStale: false
        )

        XCTAssertEqual(image.size.width, 18)
        XCTAssertEqual(image.size.height, 18)
        XCTAssertFalse(image.isTemplate)
    }

    func testAccessibilityDescriptionReadsUsage() {
        XCTAssertEqual(
            MenuBarIconRenderer.accessibilityDescription(fiveHourUsedPercent: 42.4, weeklyUsedPercent: nil, isStale: true),
            "MultiCodex: 5-hour 42% used, weekly unknown, needs attention"
        )
    }
}
