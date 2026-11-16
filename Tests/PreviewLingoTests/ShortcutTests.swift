import XCTest
@testable import PreviewLingoCore

final class ShortcutTests: XCTestCase {
    func testPhysicalDoublePress() {
        var keys = DoubleSpaceShortcut()
        XCTAssertEqual(keys.handle(keyCode: 49, isDown: true, context: "selection", timestamp: 1), .consume)
        XCTAssertEqual(keys.handle(keyCode: 49, isDown: false, context: nil, timestamp: 1.05), .consume)
        XCTAssertEqual(keys.handle(keyCode: 49, isDown: true, context: "selection", timestamp: 1.2), .trigger)
        XCTAssertEqual(keys.handle(keyCode: 49, isDown: false, context: nil, timestamp: 1.25), .consume)
    }

    func testEditingAndOtherApplicationsPassThrough() {
        var keys = DoubleSpaceShortcut()
        XCTAssertEqual(keys.handle(keyCode: 49, isDown: true, context: nil, timestamp: 1), .passThrough)
        XCTAssertEqual(keys.handle(keyCode: 49, isDown: false, context: nil, timestamp: 1.05), .passThrough)
        XCTAssertEqual(keys.handle(keyCode: 8, isDown: true, hasModifiers: true, context: nil, timestamp: 1.2), .passThrough)
    }

    func testSlowRepeatAndChangedSelectionDoNotTrigger() {
        var keys = DoubleSpaceShortcut()
        _ = keys.handle(keyCode: 49, isDown: true, context: "a", timestamp: 1)
        XCTAssertEqual(keys.handle(keyCode: 49, isDown: true, isRepeat: true, context: "a", timestamp: 1.1), .consume)
        _ = keys.handle(keyCode: 49, isDown: false, context: nil, timestamp: 1.2)
        XCTAssertEqual(keys.handle(keyCode: 49, isDown: true, context: "b", timestamp: 1.3), .consume)
        _ = keys.handle(keyCode: 49, isDown: false, context: nil, timestamp: 1.4)
        XCTAssertEqual(keys.handle(keyCode: 49, isDown: true, context: "b", timestamp: 2.5), .consume)
    }
}
