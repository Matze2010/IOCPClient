import XCTest
@testable import IOCPClient

final class IOCPClientTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(IOCPClient().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
