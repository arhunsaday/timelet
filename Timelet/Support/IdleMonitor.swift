import Foundation
import IOKit

/// System input-idle time via IOKit `HIDIdleTime` (seconds since the last keyboard/mouse event).
/// Chosen over `CGEventSource` because it needs no special permission and has no enum-rawValue pitfalls.
enum IdleMonitor {
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
              let dict = properties?.takeRetainedValue() as? [String: Any],
              let idle = dict["HIDIdleTime"] as? NSNumber else {
            return 0
        }
        return idle.doubleValue / 1_000_000_000 // nanoseconds → seconds
    }
}
