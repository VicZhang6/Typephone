# Typephone

Typephone turns an Apple Silicon Mac into a BLE HID keyboard for an iPhone or iPad.

The product is an Electron application with a native Swift helper:

- **Electron** owns the menu-bar tray, control window, permission guidance, routing controls, settings, and diagnostics export.
- **Swift** owns `CoreBluetooth`, the HOGP service tree, `CGEventTap`, Accessibility/Input Monitoring permissions, sleep/wake recovery, and the ordered HID report queue.

Electron cannot expose macOS as a BLE peripheral by itself, so the native layer is required for real HID advertising. The two processes communicate over a newline-delimited JSON protocol on loopback TCP port `43821`.

## Implemented

- BLE HOGP services with expanded SIG UUIDs (macOS rejects short-form service UUIDs)
- HID Information, Report Map, Protocol Mode, Control Point, Report Input/Output, Boot Keyboard Input/Output
- Device Information and Battery services
- encrypted input/output/notify characteristics and dynamic read values
- ordered HID notification queue with per-characteristic backpressure retry
- Mac virtual-keycode → USB HID usage mapping for letters, numbers, punctuation, navigation, keypad, function keys, and modifiers
- global `CGEventTap` for `keyDown`, `keyUp`, and `flagsChanged`
- routing modes: off, mirror, exclusive
- emergency exit: `Control + Option + Command + Escape`
- forced key release on disconnect, permission loss, sleep, wake, and shutdown
- automatic BLE service republish after Bluetooth reset/power changes
- sleep/wake monitoring and automatic rebroadcast
- permission request links for Input Monitoring and Accessibility
- diagnostic state: Bluetooth, service registration, advertising, central, subscriptions, queue depth, report bytes, LED state, permissions, capture mode, pressed keys
- JSON diagnostic export to `~/Downloads`
- Electron tray menu, control window, settings (theme & language)
- Swift unit tests for HID reports, key mapping, keyboard state, queue ordering, and 5,000 queued reports

## Run in development

```bash
npm install
npm run dev
```

`npm run dev` stamps version metadata, builds the native helper, launches it with `--electron-helper`, and starts Electron. The helper runs unsandboxed because macOS `CGEventTap` cannot operate from a sandboxed process.

Run native tests directly:

```bash
npm run test:native
```

Build an unsigned local macOS directory distribution:

```bash
npm run dist:dir
```

Production distribution still requires signing/notarization and a real Apple Developer Team. The nested Swift helper must be signed with the same distribution identity as the Electron app.

## Versioning

Typephone separates **Version Name** (user-facing semver) from **Build Number** (monotonic integer).

| Field | Example | When it changes |
|-------|---------|-----------------|
| Version Name | `1.3.0` | Formal release only (`patch` / `minor` / `major`) |
| Build Number | `258` | Every CI/dev build (or CI `run_number`) |

Source of truth: [`version.json`](./version.json). Runtime stamp (commit + display string): `electron/shared/version-stamp.js`.

```bash
# Show current version
npm run version:print

# Dev / test: increment Build Number only
npm run version:bump-build

# Formal release: bump Version Name + Build Number + stamp
npm run version:release -- patch   # or minor | major

# Write stamp + sync package.json / project.yml only
npm run version:stamp
```

Settings shows: `Version 1.3.0 (Build 258)` (tooltip includes git commit).

CI workflows:

- **CI** (PR / push to `main`): sets Build Number from `github.run_number`, does **not** change Version Name.
- **Release** (workflow_dispatch with level, or `v*.*.*` tag): bumps Version Name, stamps Build Number, packages, creates GitHub Release.

## Real-device acceptance

The code and local protocol are verified on this Mac, but the following require a real iPhone/iPad:

1. Forget any stale `Typephone Keyboard` entry on the phone.
2. Start the app and allow Input Monitoring/Accessibility when enabling routing.
3. In iPhone Settings → Bluetooth, pair `Typephone Keyboard`.
4. Open Notes and use **Send “a” to iPhone**.
5. Verify mirror, exclusive, modifiers, long-press delete, Caps Lock LED feedback, sleep/wake, Bluetooth restart, and 5,000-key stress behavior.

Chinese input remains phone-side: switch the iPhone to a Pinyin keyboard and send Latin key usages; Mac-side IME composition is not transmitted as Unicode.
