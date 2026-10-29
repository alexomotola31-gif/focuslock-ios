import DeviceActivity
import Foundation

/// Runs in its own process, started by iOS at the exact start/end of each
/// monitored interval — even if FocusLock is closed or the phone restarted.
/// This is what makes timers and schedules end reliably on time.
class FocusLockMonitor: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let parts = activity.rawValue.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return }
        let id = parts[1]

        if parts[0] == "schedule" {
            guard let item = SharedStore.schedules.first(where: { $0.id == id }), item.enabled else { return }
            if SharedStore.scheduleStart(id) == nil {
                SharedStore.setScheduleStart(Date(), id: id)
            }
            ShieldApplier.apply(name: "schedule.\(id)", selectionData: item.selectionData)
        } else if parts[0] == "timer" {
            guard let timer = SharedStore.timers.first(where: { $0.id == id }),
                  timer.endTime > Date() else { return }
            ShieldApplier.apply(name: "timer.\(id)", selectionData: timer.selectionData)
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let parts = activity.rawValue.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return }
        let id = parts[1]

        if parts[0] == "schedule" {
            ShieldApplier.clear(name: "schedule.\(id)")
            if let item = SharedStore.schedules.first(where: { $0.id == id }) {
                SharedStore.finishSchedule(item)
            }
        } else if parts[0] == "timer" {
            ShieldApplier.clear(name: "timer.\(id)")
            SharedStore.finishTimer(id: id, reason: .completed)
        }
    }
}
