import Charts
import SwiftUI

/// Activity tab content: two headline tiles over two Swift Charts bar
/// charts (this week by day, today by hour). Each chart is one series, so
/// the only legend is the meeting swatch; hovering a bar shows its exact
/// value in the chart's header row. Pure display — `PopoverModel.refresh()`
/// supplies the data.
struct ActivityPanel: View {
    let week: [DayStat]
    let day: [HourStat]
    let weekPercent: Double?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                StatTile(title: "Today", percent: todayPercent)
                Divider().frame(height: 44)
                StatTile(title: "This week", percent: weekPercent)
            }
            .padding(.vertical, 12)
            Divider()
            BarChart(title: "This week", bars: weekBars, axisValues: Array(week.indices), barWidth: 20, showsMeetingLegend: false)
                .padding(12)
            Divider()
            BarChart(title: "Today", bars: dayBars, axisValues: [0, 6, 12, 18], barWidth: 7, showsMeetingLegend: true)
                .padding(12)
        }
    }

    /// Today's entry of the week stats — already weighted by observed time.
    private var todayPercent: Double? {
        week.first { Calendar.current.isDateInToday($0.date) }?.activePercent
    }

    private var weekBars: [Bar] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return week.enumerated().map { index, stat in
            let name = formatter.string(from: stat.date)
            let isToday = Calendar.current.isDateInToday(stat.date)
            return Bar(
                index: index,
                percent: stat.activePercent,
                color: isToday ? Palette.active : Palette.activeDimmed,
                axisLabel: String(name.prefix(1)),
                readout: "\(name) · \(percentText(stat.activePercent, empty: "no data"))"
            )
        }
    }

    private var dayBars: [Bar] {
        let currentHour = Calendar.current.component(.hour, from: Date())
        return day.map { stat in
            let color: Color
            if stat.hadMeeting {
                color = Palette.meeting
            } else {
                color = stat.hour == currentHour ? Palette.active : Palette.activeDimmed
            }
            let meeting = stat.hadMeeting ? " · meeting" : ""
            return Bar(
                index: stat.hour,
                percent: stat.activePercent,
                color: color,
                axisLabel: "\(stat.hour)",
                readout: String(format: "%02d:00", stat.hour) + " · " + percentText(stat.activePercent, empty: "no data") + meeting
            )
        }
    }
}

/// Checked with the dataviz skill's validate_palette.js against the dark card
/// surface (#2C2C2C): lightness band, CVD separation and contrast all pass.
/// System orange (#FF9F0A) fails the dark lightness band, hence the darker step.
private enum Palette {
    static let active = Color(red: 0x0A / 255, green: 0x84 / 255, blue: 0xFF / 255)
    static let activeDimmed = active.opacity(0.55)
    static let meeting = Color(red: 0xD9 / 255, green: 0x78 / 255, blue: 0x00 / 255)
    static let ghost = Color.white.opacity(0.14)
    static let ghostHeight = 0.04
    static let grid = Color.white.opacity(0.08)
}

private func percentText(_ percent: Double?, empty: String) -> String {
    guard let percent else { return empty }
    return "\(Int((percent * 100).rounded()))%"
}

private struct StatTile: View {
    let title: String
    let percent: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(.secondary)
            Text(percentText(percent, empty: "—"))
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text("active")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
    }
}

private struct Bar: Identifiable {
    let index: Int
    /// Nil = no observed time: drawn as a faint baseline stub, never as a
    /// full bar (that reads as 100%) or nothing (that reads as missing).
    let percent: Double?
    let color: Color
    let axisLabel: String
    let readout: String

    var id: Int { index }
}

private struct BarChart: View {
    let title: String
    let bars: [Bar]
    let axisValues: [Int]
    let barWidth: CGFloat
    let showsMeetingLegend: Bool

    @State private var selectedIndex: Int?

    private var selectedBar: Bar? {
        guard let selectedIndex else { return nil }
        return bars.first { $0.index == selectedIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            Chart {
                ForEach(bars) { bar in
                    BarMark(
                        x: .value("Period", bar.index),
                        y: .value("Active", bar.percent ?? Palette.ghostHeight),
                        width: .fixed(barWidth)
                    )
                    .cornerRadius(3)
                    .foregroundStyle(bar.percent == nil ? Palette.ghost : bar.color)
                }
                if let selectedBar {
                    RuleMark(x: .value("Period", selectedBar.index))
                        .foregroundStyle(Color.white.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
            }
            .chartXScale(domain: -0.5...(Double(bars.count) - 0.5))
            .chartYScale(domain: 0...1)
            .chartXAxis {
                AxisMarks(values: axisValues) { value in
                    AxisValueLabel {
                        if let index = value.as(Int.self), let bar = bars.first(where: { $0.index == index }) {
                            Text(bar.axisLabel)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 0.5, 1]) { value in
                    AxisGridLine().foregroundStyle(Palette.grid)
                    AxisValueLabel {
                        if let fraction = value.as(Double.self) {
                            Text("\(Int(fraction * 100))%")
                        }
                    }
                }
            }
            .chartXSelection(value: $selectedIndex)
            .frame(height: 90)
        }
    }

    /// Title on the left; on the right the hovered bar's value, or the
    /// meeting legend when nothing is hovered.
    private var header: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(.secondary)
            Spacer()
            if let selectedBar {
                Text(selectedBar.readout)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
            } else if showsMeetingLegend {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Palette.meeting)
                        .frame(width: 8, height: 8)
                    Text("Meeting")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 14)
    }
}
