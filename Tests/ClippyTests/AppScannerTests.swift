import XCTest
@testable import Clippy

final class AppScannerTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// Builds `<root>/<dir>/<bundleName>.app` with an optional Info.plist.
    private func makeApp(_ bundleName: String, in dir: String, displayName: String? = nil) throws -> URL {
        let directory = root.appendingPathComponent(dir)
        let bundle = directory.appendingPathComponent("\(bundleName).app")
        try FileManager.default.createDirectory(
            at: bundle.appendingPathComponent("Contents"), withIntermediateDirectories: true
        )
        if let displayName {
            let plist = ["CFBundleDisplayName": displayName]
            let data = try PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0
            )
            try data.write(to: bundle.appendingPathComponent("Contents/Info.plist"))
        }
        return directory
    }

    func testFindsAppBundles() throws {
        let dir = try makeApp("Slack", in: "Applications")
        let apps = AppScanner.scan(directories: [dir])
        XCTAssertEqual(apps.map(\.name), ["Slack"])
        XCTAssertTrue(apps[0].path.hasSuffix("Slack.app"))
    }

    /// The fallback path: no Info.plist at all still yields a usable name.
    func testFallsBackToFilenameWhenNoInfoPlist() throws {
        let dir = try makeApp("Some Weird App", in: "Applications")
        XCTAssertEqual(AppScanner.scan(directories: [dir]).map(\.name), ["Some Weird App"])
    }

    func testPrefersDisplayNameFromInfoPlist() throws {
        let dir = try makeApp("Code", in: "Applications", displayName: "Visual Studio Code")
        XCTAssertEqual(AppScanner.scan(directories: [dir]).map(\.name), ["Visual Studio Code"])
    }

    func testIgnoresNonAppEntries() throws {
        let dir = root.appendingPathComponent("Applications")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "hi".write(to: dir.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("NotAnApp"), withIntermediateDirectories: true
        )
        XCTAssertTrue(AppScanner.scan(directories: [dir]).isEmpty)
    }

    func testMissingDirectoryIsSkippedNotFatal() throws {
        let dir = try makeApp("Mail", in: "Applications")
        let ghost = root.appendingPathComponent("DoesNotExist")
        XCTAssertEqual(AppScanner.scan(directories: [dir, ghost]).map(\.name), ["Mail"])
    }

    func testDeduplicatesByNameFirstDirectoryWins() throws {
        let user = try makeApp("Mail", in: "UserApps")
        let system = try makeApp("Mail", in: "SystemApps")
        let apps = AppScanner.scan(directories: [user, system])
        XCTAssertEqual(apps.count, 1)
        XCTAssertTrue(apps[0].path.contains("UserApps"))
    }

    func testResultsAreSortedByName() throws {
        _ = try makeApp("Zulip", in: "Applications")
        let dir = try makeApp("Alacritty", in: "Applications")
        XCTAssertEqual(AppScanner.scan(directories: [dir]).map(\.name), ["Alacritty", "Zulip"])
    }
}
