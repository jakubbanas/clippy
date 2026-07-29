/// Compile-time feature registry. Add new features here.
enum Registry {
    static func builtInFeatures() -> [Feature] {
        // M3 adds: CalendarFeature()
        return []
    }
}
