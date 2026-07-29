import XCTest
@testable import Clippy

final class MeetingLinksTests: XCTestCase {
    func testFindsZoomLink() {
        let url = MeetingLinks.firstLink(in: "Join here: https://fandom.zoom.us/j/123456789?pwd=abc please")
        XCTAssertEqual(url?.absoluteString, "https://fandom.zoom.us/j/123456789?pwd=abc")
    }

    func testFindsBareZoomLink() {
        let url = MeetingLinks.firstLink(in: "https://zoom.us/j/999")
        XCTAssertEqual(url?.absoluteString, "https://zoom.us/j/999")
    }

    func testFindsMeetLink() {
        let url = MeetingLinks.firstLink(in: "meet at https://meet.google.com/abc-defg-hij today")
        XCTAssertEqual(url?.absoluteString, "https://meet.google.com/abc-defg-hij")
    }

    func testFindsTeamsLink() {
        let url = MeetingLinks.firstLink(in: "https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0?context=y")
        XCTAssertEqual(url?.absoluteString, "https://teams.microsoft.com/l/meetup-join/19%3ameeting_x/0?context=y")
    }

    func testNoLinkReturnsNil() {
        XCTAssertNil(MeetingLinks.firstLink(in: "lunch with Sam at https://example.com/menu"))
    }

    func testFindsLinkInsideHTMLHrefAttribute() {
        let notes = #"<p>Join: <a href="https://meet.google.com/abc-defg-hij">link</a></p>"#
        let url = MeetingLinks.firstLink(in: MeetingLinks.normalizeHTML(notes))
        XCTAssertEqual(url?.absoluteString, "https://meet.google.com/abc-defg-hij")
    }

    func testHTMLEntityAmpersandInZoomURL() {
        let notes = "https://zoom.us/j/123?pwd=a&amp;uname=b"
        let url = MeetingLinks.firstLink(in: MeetingLinks.normalizeHTML(notes))
        XCTAssertEqual(url?.absoluteString, "https://zoom.us/j/123?pwd=a&uname=b")
    }

    func testExtractPrefersEventURLField() {
        let event = makeEvent(
            url: URL(string: "https://zoom.us/j/111"),
            location: "https://zoom.us/j/222"
        )
        XCTAssertEqual(MeetingLinks.extract(from: event)?.absoluteString, "https://zoom.us/j/111")
    }

    func testExtractFallsBackToLocationThenNotes() {
        let event = makeEvent(url: URL(string: "https://example.com/not-a-meeting"), location: nil, notes: "call: https://meet.google.com/xyz-abcd-efg")
        XCTAssertEqual(MeetingLinks.extract(from: event)?.absoluteString, "https://meet.google.com/xyz-abcd-efg")
    }

    private func makeEvent(url: URL? = nil, location: String? = nil, notes: String? = nil) -> EventInfo {
        EventInfo(
            id: "test",
            title: "Test",
            start: Date(),
            end: Date().addingTimeInterval(1800),
            location: location,
            notes: notes,
            url: url,
            isAllDay: false,
            isDeclined: false,
            calendarTitle: "Work"
        )
    }
}
