import XCTest
@testable import Clippy

final class AgentDataTests: XCTestCase {
    func testDecodesMinimalAgentData() throws {
        let json = """
        {
          "framesize": [124, 93],
          "animations": {
            "Wave": {
              "frames": [
                { "duration": 100, "images": [[0, 0]] },
                { "duration": 100 }
              ]
            }
          }
        }
        """
        let data = try JSONDecoder().decode(AgentData.self, from: Data(json.utf8))
        XCTAssertEqual(data.frameWidth, 124)
        XCTAssertEqual(data.frameHeight, 93)
        XCTAssertEqual(data.animations["Wave"]?.frames.count, 2)
        XCTAssertNil(data.animations["Wave"]?.frames[1].images)
    }
}
