# Local development

This checkout is based on `Mikeli7666/DuoBar` main at `8352201`.

Run `./script/build_and_run.sh --verify` from this directory, or use the Codex
Run button. Requires full Xcode at `/Applications/Xcode.app`; set
`DEVELOPER_DIR` if Xcode is installed elsewhere.

The script builds a local Release version (1.5.0, build 8) with an ad-hoc
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

Run `./script/package_dmg.sh`. It builds both arm64 and x86_64, verifies the app signature and version, creates a read-only compressed DMG, verifies the image, and writes SHA256SUMS under `build/releases/1.5.0/`. Existing output is preserved; move it aside before another packaging run.

The image includes DuoBar.app, an Applications shortcut, the MIT license, and bilingual installation notes. It does not install anything or replace the currently running app. Packaging uses an ad-hoc signature, not Developer ID or notarization. GitHub publication is a separate step.
