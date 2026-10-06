import XCTest
@testable import Clippy

final class PopoverModelTests: XCTestCase {
    func testStartsOnActivityTab() {
        XCTAssertEqual(PopoverModel().selectedTab, .activity)
    }

    func testSetClippyHiddenStoresAndForwards() {
        let model = PopoverModel()
        var forwarded: Bool?
        model.onSetClippyHidden = { forwarded = $0 }

        model.setClippyHidden(true)

        XCTAssertTrue(model.isClippyHidden)
        XCTAssertEqual(forwarded, true)
    }

    func testSetStartsAtLoginAppliesSuccessfulChange() {
        let model = PopoverModel()
        model.onSetStartsAtLogin = { $0 }

        model.setStartsAtLogin(true)

        XCTAssertTrue(model.startsAtLogin)
    }

    /// Registration can fail (e.g. an unsigned build). The toggle must show
    /// what the service actually reports, not what was asked for.
    func testSetStartsAtLoginKeepsStateReportedByService() {
        let model = PopoverModel()
        model.onSetStartsAtLogin = { _ in false }

        model.setStartsAtLogin(true)

        XCTAssertFalse(model.startsAtLogin)
    }
}
