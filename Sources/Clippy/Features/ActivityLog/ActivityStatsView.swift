import AppKit

/// Two "meter" bar charts — current week (day meters) and current day (hour
/// meters). Each bar is a single metric (% active within observed time): an
/// accent-colored fill against a faint track, the way Apple's own
/// activity/usage meters read — not a two-tone stacked bar. A period with
/// zero observed time draws as an empty outlined "ghost" bar instead of a
/// false 0%/100% fill. Hours with a meeting get a thin orange ring. Pure
/// display: no timers, no live refresh — `configure` is called once when
/// the window opens.
final class ActivityStatsView: NSView {
    private var week: [DayStat] = []
    private var day: [HourStat] = []

    private let fillColor = NSColor.controlAccentColor
    private let trackColor = NSColor.quaternaryLabelColor
    private let ghostColor = NSColor.tertiaryLabelColor
    private let meetingRingColor = NSColor.systemOrange

    /// SF Symbol for the meeting legend, pre-tinted orange — same iconography
    /// language as the rest of macOS, instead of a plain drawn dot.
    private lazy var meetingIcon: NSImage? = {
        NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(paletteColors: [meetingRingColor]))
    }()

    func configure(week: [DayStat], day: [HourStat]) {
        self.week = week
        self.day = day
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let padding: CGFloat = 20
        let titleHeight: CGFloat = 20
        let labelHeight: CGFloat = 16
        let blockHeight = (bounds.height - padding * 3) / 2
        let barsHeight = blockHeight - titleHeight - labelHeight
        // Uppercase, tracked, secondary-ink section headers — the same style
        // macOS uses for group headers in System Settings / Notification Center,
        // rather than a bold primary-ink title.
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.secondaryLabelColor,
            .kern: 0.6,
        ]

        let weekBlockTop = bounds.height - padding
        "THIS WEEK".draw(at: NSPoint(x: padding, y: weekBlockTop - titleHeight), withAttributes: titleAttrs)
        let weekBarsRect = NSRect(
            x: padding,
            y: weekBlockTop - blockHeight + labelHeight,
            width: bounds.width - padding * 2,
            height: barsHeight
        )
        drawChart(
            in: weekBarsRect,
            count: week.count,
            maxBarWidth: 24,
            activePercent: { self.week[$0].activePercent },
            hadMeeting: { _ in false },
            label: { self.dayLabel(for: self.week[$0].date) }
        )

        let dayBlockBottom = padding
        "TODAY".draw(at: NSPoint(x: padding, y: dayBlockBottom + blockHeight - titleHeight), withAttributes: titleAttrs)
        let dayBarsRect = NSRect(
            x: padding,
            y: dayBlockBottom + labelHeight,
            width: bounds.width - padding * 2,
            height: barsHeight
        )
        drawChart(
            in: dayBarsRect,
            count: day.count,
            maxBarWidth: 14,
            activePercent: { self.day[$0].activePercent },
            hadMeeting: { self.day[$0].hadMeeting },
            label: { $0 % 3 == 0 ? "\(self.day[$0].hour)" : "" }
        )

        drawMeetingLegend()
    }

    private func drawChart(
        in rect: NSRect,
        count: Int,
        maxBarWidth: CGFloat,
        activePercent: (Int) -> Double?,
        hadMeeting: (Int) -> Bool,
        label: (Int) -> String
    ) {
        guard count > 0 else { return }
        let slotWidth = rect.width / CGFloat(count)
        let barWidth = min(maxBarWidth, slotWidth - 4)
        let cornerRadius = min(3, barWidth / 2, rect.height / 2)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]

        for index in 0..<count {
            let slotX = rect.minX + CGFloat(index) * slotWidth
            let barX = slotX + (slotWidth - barWidth) / 2
            let barRect = NSRect(x: barX, y: rect.minY, width: barWidth, height: rect.height)
            let barPath = NSBezierPath(roundedRect: barRect, xRadius: cornerRadius, yRadius: cornerRadius)

            if let percent = activePercent(index) {
                trackColor.setFill()
                barPath.fill()

                NSGraphicsContext.current?.saveGraphicsState()
                barPath.addClip()
                let activeHeight = rect.height * CGFloat(percent)
                fillColor.setFill()
                NSBezierPath(rect: NSRect(x: barRect.minX, y: barRect.minY, width: barWidth, height: activeHeight)).fill()
                NSGraphicsContext.current?.restoreGraphicsState()
            } else {
                ghostColor.setStroke()
                barPath.lineWidth = 1
                barPath.stroke()
            }

            if hadMeeting(index) {
                meetingRingColor.setStroke()
                let ring = NSBezierPath(roundedRect: barRect.insetBy(dx: 0.75, dy: 0.75), xRadius: cornerRadius, yRadius: cornerRadius)
                ring.lineWidth = 1.5
                ring.stroke()
            }

            let text = label(index)
            if !text.isEmpty {
                let size = text.size(withAttributes: labelAttrs)
                let point = NSPoint(x: barRect.midX - size.width / 2, y: rect.minY - 13)
                text.draw(at: point, withAttributes: labelAttrs)
            }
        }
    }

    private func drawMeetingLegend() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let text = "Meeting"
        let size = text.size(withAttributes: attrs)
        let iconSize: CGFloat = 11
        let iconRect = NSRect(x: bounds.width - 18 - size.width - iconSize - 4, y: bounds.height - 18, width: iconSize, height: iconSize)
        meetingIcon?.draw(in: iconRect)
        text.draw(at: NSPoint(x: iconRect.maxX + 4, y: bounds.height - 19), withAttributes: attrs)
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
