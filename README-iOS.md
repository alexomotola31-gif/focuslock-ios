# FocusLock for iOS

SwiftUI port of the Android FocusLock. Locks are enforced by iOS itself
(FamilyControls + ManagedSettings), so they survive the app being killed or
the phone restarting.

## Not compiled yet
This code was written without Xcode. First step: push to GitHub and run the
"iOS compile check" workflow (Actions tab). It builds on a free macOS runner and
shows any compile errors. Send me the log and I'll fix them.

## Build
1. `brew install xcodegen && xcodegen generate` (project.yml -> FocusLock.xcodeproj)
2. Set `DEVELOPMENT_TEAM` in project.yml to your Apple Team ID.
3. In the Apple developer portal: register App ID `com.alex.focuslock`, plus
   `.monitor` and `.shield` variants, and App Group `group.com.alex.focuslock`.
4. Request the Family Controls (Distribution) entitlement for all three IDs:
   https://developer.apple.com/contact/request/family-controls/
5. Build to a real device (Simulator can't do Screen Time). Requires the paid
   Apple Developer Program.

## Parity with Android
| Feature | iOS |
|---|---|
| Timer lock, strict, per-session 6-digit code, 3 uses/day, 60s cooldown | yes |
| Several timers at once | yes (separate shield stores) |
| Recurring schedules, strict (no code), overlapping, warnings | yes |
| Schedule can't be edited/disabled/deleted mid-window | yes |
| Pomodoro | 25-min focus block (no automatic break chain) |
| Real app icons/names + whole categories | yes, via Apple's picker |
| Insights, daily goal, streak, achievements, history | yes |
| Themes (mode, accent, text size), splash, logo | yes |
| Shortcut to start a lock | yes (Shortcuts / Action Button) |
| Setup checklist | yes (Screen Time, notifications, apps) |
| Widget, focus sounds, ads, auto-update | not yet |
| Auto-sorting installed apps | n/a - iOS hides the app list; Apple's categories replace it |

## iOS limits
- Timers/schedule windows must be at least 15 minutes (DeviceActivity rule).
- Revoking Screen Time access in Settings or deleting the app removes locks.
