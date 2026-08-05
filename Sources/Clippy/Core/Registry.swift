/// Compile-time feature registry. Add new features here.
enum Registry {
    static func builtInFeatures() -> [Feature] {
        return [
            CalendarFeature(),
            NudgesFeature(),
            FocusSessionFeature(),
            BreakTrackerFeature(),
            ActivityLogFeature()
        ]
    }
}
