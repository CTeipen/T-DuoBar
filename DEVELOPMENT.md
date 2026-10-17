# Local development

This checkout is based on `Mikeli7666/DuoBar` main at `8352201`.

Run `./script/build_and_run.sh --verify` from this directory, or use the Codex
Run button. Requires full Xcode at `/Applications/Xcode.app`; set
`DEVELOPER_DIR` if Xcode is installed elsewhere.

The script builds a local Release version (1.9.0, build 18) with an ad-hoc
signature, verifies it, stops existing DuoBar instances, and installs it in
`/Applications/DuoBar.app`. The previous installed app is moved intact to
`~/Library/Application Support/T-DuoBar/Backups/` before replacement. Launch
verification checks that the running process is actually from `/Applications`.
The local build is not a Developer ID signed or notarized public release.

`--debug` launches the temporary Debug build under LLDB instead of installing.

## Battery time

The Battery section in the popover shows estimated time until empty when
running on battery, or time until full charge while charging. The menu-bar
icon remains unchanged. Estimates come from macOS IOKit and refresh on power
notifications and every 60 seconds.

Unavailable estimates and connected-but-not-charging states have explicit
messages. Fully charged and unavailable batteries do not show a time estimate.

Focused checks:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project DuoBar.xcodeproj -scheme DuoBar -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$TMPDIR/T-DuoBar-DerivedData" \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  -only-testing:DuoBarTests/BatteryTimeTests \
  -only-testing:DuoBarTests/SystemStatusModelTests \
  -only-testing:DuoBarTests/LocalizationTests test
```

Use `arch=x86_64` on an Intel Mac. Charging/discharging estimates need a manual
check with a real battery and charger; automated cases use simulated states.

## Local 1.5.0 features

- Expand Network for signal, band, channel, IPv4 address, clipboard copy and Wi-Fi power.
- Expand Battery for adapter wattage and power state; keep the battery time estimate optional.
- Connected accessory batteries from Apple's local Bluetooth report. Polls while the popover section is visible; disconnected cached readings are excluded. Device support and separate AirPods/case readings depend on what macOS reports.
- Expand Audio Output to select a device or star favorite outputs. Favorites use persistent device UIDs.
- Enable Microphone in Settings → Menu sections to select the default input device. This changes Core Audio routing; DuoBar does not record microphone audio.
- Settings → Notifications enables one low-battery alert on crossing 10%, 20% or 30%. Defaults off; authorization is requested when enabling it. Initial startup below a threshold does not issue an alert. Charging or recovery above the threshold plus 5% rearms the alert.
- Menu sections can be hidden independently. Expanded content scrolls when it reaches the screen-height cap.

Charge-limit readout remains Unavailable: a reliable public source has not been identified. No limit is inferred from a paused charge or an 80% reading. Adapter wattage is the reported adapter rating, not a measurement of current charging power.

The full test suite includes hardware-dependent tests that skip when devices or explicit hardware validation flags are absent. Physical accessory and microphone selection checks still require the corresponding devices.

## Experimental DMG packaging

Run `./script/package_dmg.sh`. It builds both arm64 and x86_64, verifies the app signature and version, creates a read-only compressed DMG, verifies the image, and writes SHA256SUMS under `build/releases/1.9.0/`. Existing output is preserved; move it aside before another packaging run.

The image includes DuoBar.app, an Applications shortcut, the MIT license, and bilingual installation notes. It does not install anything or replace the currently running app. Packaging uses an ad-hoc signature, not Developer ID or notarization. GitHub publication is a separate step.

## Homebrew publishing and weekly checks

After publishing and verifying a DMG release, prepare the tap with:

```sh
./script/publish_homebrew.py 1.9.0 18 --tap-dir /path/to/homebrew-tap
```

The helper uses GitHub's uploaded-asset SHA-256 and fixed repository/asset URLs. Review, commit and push the cask and manifest together. The app reads https://raw.githubusercontent.com/squazaryu/homebrew-tap/main/updates/t-duobar.json; it checks only versions available in the tap, including our experimental releases.

A check runs at startup, on wake and from an hourly due-date timer, but makes no network request unless seven days have elapsed since a successful check. Network failures have a six-hour backoff. Check timestamps, cached version and last-notified version persist across restarts. Notifications require macOS permission. The manifest supplies only validated version/build data, never a command or script to execute.

The bundled UpdateWithHomebrew.command runs fixed Homebrew commands in Terminal after an explicit installation click. It preserves a manually installed app before adopting Homebrew management, retains preferences, and reopens DuoBar. No other casks are upgraded. App-managed installation of arbitrary downloaded binaries is not implemented.

## Local 1.6.2 stability changes

Accessory polling is owned by the actual NSPopover show/close events and its visibility preference. Rendering a retained or offscreen SwiftUI view does not start system_profiler. Closing the popover cancels both the waiting task and its detached worker; late results cannot overwrite a reopened menu. Only completed reports enter the short-lived cache. The owned helper is terminated and reaped on cancellation or timeout, with a bounded grace period before a forced termination if needed.

Background battery, network, accessory and update timers have tolerances for system timer coalescing. Event-driven updates remain immediate. AccessoryPollingLifecycleTests covers cancellation, reopening, caching, hidden-view rendering, preference changes, helper cancellation and a helper that ignores termination. Local diagnostic captures live under the ignored build/stability-audit directory. The current published release remains separate from this local development build.

## Local 1.7.0 identity

T-DuoBar has its own reproducible AppIcon and a standard native macOS About panel. Open it from Settings → General → About T-DuoBar, the popover title, the application menu, or by reopening the running app from Finder. It reads version/build directly from the installed bundle and credits the upstream author with links to both projects and the MIT license. It creates no background service. The menu-bar status glyph retains its existing behavior.

Regenerate the icon's ten macOS asset sizes from the vector drawing code with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift script/render_app_icon.swift
```

The display name is T-DuoBar. The installed path remains `/Applications/DuoBar.app` and the bundle identifier remains `com.mikeli.duobar`, preserving Homebrew management and existing preferences.

## Local 1.8.0 compact settings and context menu

Settings now use three native tabs: General, Notifications and Updates. Existing preference keys and values are preserved. About and version/build remain in the shared footer. General groups appearance, visible sections, battery and behavior; developer-only diagnostics are collapsed and constructed only when expanded. Update commands remain available under a disclosure group.

Right-click or Control-click the status item to open the native Settings / Check for updates / Quit menu. Left-click retains the status popover. Context-menu tracking temporarily suppresses hover popovers, closes an already open popover, and restores normal hover behavior after dismissal. Settings routing uses the actual localized SwiftUI command in the app menu rather than a hard-coded private selector.

## Local 1.9.0 menu customization and connection status

General → Menu sections supports dragging the handles to reorder the six sections. Right-click a row for Move up / Move down, or use the equivalent accessibility actions. Reset order restores the default sequence without changing visibility. The order uses stable IDs in `menu.sectionOrder`; unknown IDs and duplicates are ignored, and newly introduced or missing sections are appended. Existing preferences require no migration.

The status-item tooltip shows battery percentage, power state and the current time estimate, following Show battery time. It observes the existing status store and adds no timer, scan or hardware read. Network, battery, volume, audio-device and accessory sections have labeled links to their System Settings panes. If a pane URL cannot be opened, the opener falls back to System Settings itself. Wi-Fi privacy explanations use the actual Core Location authorization state; unavailable estimates and accessory readings are described without fabricating data or permission failures.

Connected Wi-Fi marked expensive by the existing `NWPathMonitor` uses the native `personalhotspot` chain symbol in both the menu-bar glyph and the network section. [Apple documents Personal Hotspot as an example of an expensive path](https://developer.apple.com/documentation/network/nwpath/isexpensive). This is a presentation heuristic for system-reported metered Wi-Fi: it does not identify the access point hardware. A phone that is not marked expensive keeps the regular Wi-Fi symbol; another metered Wi-Fi network may use the chain. SSID names, private CoreWLAN properties, nearby-network scans and external requests are not used. Battery/volume presentation and temporary audio-device feedback retain their existing priority.

No global keyboard shortcut is registered. This local build is separate from GitHub and Homebrew publication.

Build 17 also keeps System Settings actions inside each card's shared background, with aligned right padding. Empty accessory state is a compact 48-point row matching the other sections; connected-device levels remain visible and read failures retain explanation/retry controls. Accessory view rendering still does not start polling.

The power bolt now clears the ring's inner edge. While it appears, the center glyph scales and moves slightly down using the same animation progress; unplugging restores its normal geometry and fades the bolt at its existing position. Timing, reduced-motion behavior and color preferences remain unchanged. A bounds regression test first failed on the previous geometry and now passes for all supported icon scales. The charging render gallery includes regular Wi-Fi, hotspot, Ethernet and audio glyphs at native menu-bar size and magnified in both appearances.

Build 18 aligns the root scroll view to the top of its hosting area. During disclosure changes, AppKit and SwiftUI may briefly disagree about the popover height; the default center alignment formerly introduced blank space above the title. A render regression exercises that size mismatch and verifies the title remains in the upper strip.
