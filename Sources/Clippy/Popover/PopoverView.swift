import AppKit
import SwiftUI

/// The status-bar popover, styled after Vorssaint's panels: centered logo,
/// icon tab strip, uppercase section label, one rounded card, footer buttons.
/// Always rendered dark — `AppDelegate` forces `.darkAqua` on the popover,
/// so the white-opacity fills below are tuned for a dark background only.
struct PopoverView: View {
    @Bindable var model: PopoverModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("📎")
                .font(.system(size: 28))
                .frame(maxWidth: .infinity)

            TabStrip(selection: $model.selectedTab)

            Text(model.selectedTab.title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .kerning(0.6)
                .foregroundStyle(.secondary)

            Card {
                switch model.selectedTab {
                case .activity:
                    ActivityPanel(week: model.week, day: model.day, weekPercent: model.weekPercent)
                case .controls:
                    ControlsTab(model: model)
                }
            }

            HStack(spacing: 10) {
                FooterButton(title: "Settings", symbol: "gearshape", action: model.onOpenSettings)
                FooterButton(title: "Quit", symbol: "power", action: model.onQuit)
            }
        }
        .padding(16)
        // 320pt card content + 16pt padding each side.
        .frame(width: 352)
    }
}

extension PopoverModel.Tab {
    var title: String {
        switch self {
        case .activity: return "Activity"
        case .controls: return "Controls"
        }
    }

    var symbol: String {
        switch self {
        case .activity: return "chart.bar"
        case .controls: return "slider.horizontal.3"
        }
    }
}

private enum Style {
    static let fill = Color.white.opacity(0.06)
    static let border = Color.white.opacity(0.08)
}

private struct TabStrip: View {
    @Binding var selection: PopoverModel.Tab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PopoverModel.Tab.allCases, id: \.self) { tab in
                let isSelected = selection == tab
                Button { selection = tab } label: {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(tab.title)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12).fill(Style.fill))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Style.border))
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Style.fill))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Style.border))
    }
}

private struct ControlsTab: View {
    @Bindable var model: PopoverModel

    var body: some View {
        VStack(spacing: 0) {
            ControlRow(title: "Test Clippy", symbol: "play.circle") {
                Button("Show", action: model.onTestClippy)
            }
            Divider()
            ControlRow(title: "Hide Clippy", symbol: "eye.slash") {
                Toggle("", isOn: Binding(get: { model.isClippyHidden }, set: { model.setClippyHidden($0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            Divider()
            ControlRow(title: "Start at Login", symbol: "power.circle") {
                Toggle("", isOn: Binding(get: { model.startsAtLogin }, set: { model.setStartsAtLogin($0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            Divider()
            ControlRow(title: "Reload Config", symbol: "arrow.clockwise") {
                Button("Reload", action: model.onReloadConfig)
            }
        }
        .padding(.horizontal, 12)
    }
}

private struct ControlRow<Accessory: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
            Spacer()
            accessory
        }
        .frame(minHeight: 40)
    }
}

private struct FooterButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Style.fill))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Style.border))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
