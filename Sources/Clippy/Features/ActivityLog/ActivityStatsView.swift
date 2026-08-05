import AppKit

/// Two simple bar charts — current week (day bars) and current day (hour
/// bars) — each bar split into active (green) vs idle (gray) as a fraction
/// of that period's *observed* time only. A period with zero observed time
/// draws as an empty gray placeholder bar instead of a false 0%/100% split.
/// Hours with `hadMeeting == true` get a blue outline. Pure display: no
/// timers, no live refresh — `configure` is called once when the window opens.
final class ActivityStatsView: NSView {
    private var week: [DayStat] = []
    private var day: [HourStat] = []

    private let activeColor = NSColor.systemGreen
    private let idleColor = NSColor.systemGray
    private let meetingBorderColor = NSColor.systemBlue
    private let placeholderColor = NSColor.separatorColor

    func configure(week: [DayStat], day: [HourStat]) {
        self.week = week
        self.day = day
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: bounds).fill()

        let padding: CGFloat = 16
        let labelHeight: CGFloat = 14
        let chartAreaHeight = (bounds.height - padding * 3) / 2

        let weekChartRect = NSRect(
            x: padding,
            y: bounds.height - padding - chartAreaHeight + labelHeight,
            width: bounds.width - padding * 2,
            height: chartAreaHeight - labelHeight
        )
        drawChart(
            in: weekChartRect,
            count: week.count,
            activePercent: { self.week[$0].activePercent },
            hadMeeting: { _ in false },
            label: { self.dayLabel(for: self.week[$0].date) }
        )

        let dayChartRect = NSRect(
            x: padding,
            y: padding + labelHeight,
            width: bounds.width - padding * 2,
            height: chartAreaHeight - labelHeight
        )
        drawChart(
            in: dayChartRect,
            count: day.count,
            activePercent: { self.day[$0].activePercent },
            hadMeeting: { self.day[$0].hadMeeting },
            label: { $0 % 3 == 0 ? "\(self.day[$0].hour)" : "" }
        )
    }

    private func drawChart(
        in rect: NSRect,
        count: Int,
        activePercent: (Int) -> Double?,
        hadMeeting: (Int) -> Bool,
        label: (Int) -> String
    ) {
        guard count > 0 else { return }
        let spacing: CGFloat = 4
        let barWidth = (rect.width - spacing * CGFloat(count - 1)) / CGFloat(count)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]

        for index in 0..<count {
            let x = rect.minX + CGFloat(index) * (barWidth + spacing)
            let barRect = NSRect(x: x, y: rect.minY, width: barWidth, height: rect.height)

            if let percent = activePercent(index) {
                let activeHeight = rect.height * CGFloat(percent)
                let activeRect = NSRect(x: barRect.minX, y: barRect.minY, width: barWidth, height: activeHeight)
                let idleRect = NSRect(x: barRect.minX, y: barRect.minY + activeHeight, width: barWidth, height: barRect.height - activeHeight)
                activeColor.setFill()
                NSBezierPath(rect: activeRect).fill()
                idleColor.setFill()
                NSBezierPath(rect: idleRect).fill()
            } else {
                placeholderColor.setFill()
                NSBezierPath(rect: barRect).fill()
            }

            if hadMeeting(index) {
                meetingBorderColor.setStroke()
                let border = NSBezierPath(rect: barRect.insetBy(dx: 1, dy: 1))
                border.lineWidth = 2
                border.stroke()
            }

            let text = label(index)
            if !text.isEmpty {
                let size = text.size(withAttributes: labelAttrs)
                let point = NSPoint(x: barRect.midX - size.width / 2, y: rect.minY - 14)
                text.draw(at: point, withAttributes: labelAttrs)
            }
        }
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
