import Foundation
import IOKit

/// Reads how long the user has been idle (no keyboard/mouse input) from the HID
/// system. Used to suppress nudges while you're away — asleep, in a meeting, off
/// the machine — instead of nagging on a clock. Needs no special permission.
enum UserActivity {
    /// Seconds since the last input event. Returns 0 (treated as "active") if the
    /// HID property can't be read, so a detection failure fails open rather than
    /// silencing nudges forever.
    static func idleSeconds() -> TimeInterval {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"), &iterator) == KERN_SUCCESS else {
            return 0
        }
        defer { IOObjectRelease(iterator) }

        let entry = IOIteratorNext(iterator)
        guard entry != 0 else { return 0 }
        defer { IOObjectRelease(entry) }

        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = properties?.takeRetainedValue() as? [String: Any],
              let idleNanoseconds = (props["HIDIdleTime"] as? NSNumber)?.uint64Value else {
            return 0
        }
        return TimeInterval(idleNanoseconds) / 1_000_000_000
    }
}
