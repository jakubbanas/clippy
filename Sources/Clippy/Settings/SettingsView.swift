import SwiftUI

/// Sidebar of sections, one `Form` per section. Every control writes to
/// `SettingsModel`, which validates and saves.
struct SettingsView: View {
    @Bindable var model: SettingsModel
    @State private var section: SettingsSection? = .calendar

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.symbol).tag(item)
            }
            .navigationSplitViewColumnWidth(170)
        } detail: {
            Form {
                switch section ?? .calendar {
                case .calendar: calendar
                case .nudges: nudges
                case .focus: focus
                case .breaks: breaks
                case .launcher: launcher
                case .activityLog: activityLog
                case .clipboard: clipboard
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: Sections

    @ViewBuilder private var calendar: some View {
        Section {
            Toggle("Remind me about meetings", isOn: $model.config.calendar.enabled)
            TextField("Remind me before (minutes)", text: $model.leadMinutesText)
            ErrorText(model.leadMinutesError)
            Picker("Open meeting links in", selection: $model.config.browser) {
                Text("System default").tag(String?.none)
                ForEach(model.availableBrowsers) { browser in
                    Text(browser.name).tag(String?.some(browser.id))
                }
            }
        }
        Section("Calendars") {
            if model.availableCalendars.isEmpty {
                Text("Calendar access needed — grant it in System Settings › Privacy & Security › Calendars.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.availableCalendars, id: \.self) { title in
                    Toggle(title, isOn: Binding(
                        get: { model.isCalendarSelected(title) },
                        set: { model.setCalendar(title, selected: $0) }
                    ))
                    .toggleStyle(.checkbox)
                }
                ErrorText(model.calendarsError)
            }
        }
    }

    @ViewBuilder private var nudges: some View {
        ForEach(model.nudges.indices, id: \.self) { index in
            let nudge = nudgeBinding(index)
            Section {
                HStack {
                    Toggle("On", isOn: nudge.enabled).labelsHidden()
                    TextField("Name", text: nudge.name)
                    Button {
                        model.nudges.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove this nudge")
                }
                Stepper(value: nudge.everyMinutes, in: 1...600) {
                    Text("Every \(Int(nudge.wrappedValue.everyMinutes)) min")
                }
                TextField("Message", text: nudge.message)
            }
        }
        Section {
            ErrorText(model.nudgesError)
            Button {
                model.nudges.append(NudgeConfig(name: "Nudge \(model.nudges.count + 1)"))
            } label: {
                Label("Add nudge", systemImage: "plus.circle")
            }
        }
    }

    @ViewBuilder private var focus: some View {
        Section {
            Toggle("Focus sessions", isOn: $model.config.focus.enabled)
            Stepper(value: $model.config.focus.defaultMinutes, in: 1...600, step: 5) {
                Text("Default length: \(Int(model.config.focus.defaultMinutes)) min")
            }
            Toggle("Halfway check-in", isOn: $model.config.focus.midCheckIn)
        }
    }

    @ViewBuilder private var breaks: some View {
        Section {
            Toggle("Welcome back after breaks", isOn: $model.config.breakTracker.enabled)
            Stepper(value: $model.config.breakTracker.minBreakMinutes, in: 1...240) {
                Text("Shortest break: \(Int(model.config.breakTracker.minBreakMinutes)) min")
            }
        }
    }

    @ViewBuilder private var launcher: some View {
        Section {
            TextField("Hotkey", text: $model.hotkeyText)
            ErrorText(model.hotkeyError)
            Toggle("Search apps", isOn: $model.config.appLauncher.enabled)
        }
    }

    @ViewBuilder private var activityLog: some View {
        Section {
            Toggle("Log active time", isOn: $model.config.activityLog.enabled)
            Stepper(value: $model.config.activityLog.idleThresholdSeconds, in: 15...600, step: 5) {
                Text("Idle after: \(Int(model.config.activityLog.idleThresholdSeconds)) s")
            }
        }
    }

    @ViewBuilder private var clipboard: some View {
        Section {
            Toggle("Clipboard history", isOn: $model.config.clipboard.enabled)
            // A String draft, not TextField(value:): that commits only on Return
            // or focus loss, so closing the window could drop the typed value.
            TextField("Clips to keep", text: $model.maxClipsText)
            ErrorText(model.maxClipsError)
        }
    }

    /// Bounds-checked: a row's bindings can still be read for one render after
    /// "−" removes it, and indexing straight into the array would trap.
    private func nudgeBinding(_ index: Int) -> Binding<NudgeConfig> {
        Binding(
            get: { model.nudges.indices.contains(index) ? model.nudges[index] : NudgeConfig() },
            set: { if model.nudges.indices.contains(index) { model.nudges[index] = $0 } }
        )
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case calendar, nudges, focus, breaks, launcher, activityLog, clipboard

    var id: Self { self }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .nudges: return "Nudges"
        case .focus: return "Focus"
        case .breaks: return "Breaks"
        case .launcher: return "Launcher"
        case .activityLog: return "Activity log"
        case .clipboard: return "Clipboard"
        }
    }

    var symbol: String {
        switch self {
        case .calendar: return "calendar"
        case .nudges: return "bell"
        case .focus: return "timer"
        case .breaks: return "cup.and.saucer"
        case .launcher: return "command"
        case .activityLog: return "chart.bar"
        case .clipboard: return "clipboard"
        }
    }
}

/// Red caption under a field; renders nothing when there is no error.
private struct ErrorText: View {
    let message: String?
    init(_ message: String?) { self.message = message }

    var body: some View {
        if let message {
            Text(message).font(.caption).foregroundStyle(.red)
        }
    }
}
