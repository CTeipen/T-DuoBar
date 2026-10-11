# T-DuoBar

A community fork of [DuoBar by Mikeli7666](https://github.com/Mikeli7666/DuoBar), with extended battery, network, and audio controls for the macOS menu bar.

[Русский](README.ru.md) · [Development and local installation](DEVELOPMENT.md) · [Original project](https://github.com/Mikeli7666/DuoBar)

## Homebrew installation and updates

```sh
brew install --cask squazaryu/tap/t-duobar
brew update
brew upgrade --cask squazaryu/tap/t-duobar
```

If DuoBar was installed manually, quit it and back up `/Applications/DuoBar.app` before the first Homebrew install. `--adopt` only accepts an identical copy; do not use `--force` to discard an existing installation.

Starting with 1.6.0, DuoBar checks the published Homebrew manifest weekly while running and after launch/wake when a check is due. It notifies once per new version, subject to macOS notification permission. Click **Install with Homebrew** to open Terminal and run the bundled update script, then restart DuoBar. Updates are not installed without a click. If Homebrew is missing, the script displays instructions instead of installing the package manager automatically.

Settings → Application updates provides a weekly-check toggle, manual check, installation prompt, release notes and a copyable update command. No update check is performed while DuoBar is closed; a missed check runs after the next launch. Failed checks retry after six hours, not continuously.

Starting with 1.6.1, settings always show the installed version and build number. Every manual check shows a dialog: the installed and available versions with an installation button, confirmation that the installed version is current, or a connection error. Weekly update notifications also identify the installed and available versions. Manual-check dialogs do not require macOS notification permission.

## Version 1.6.1 (build 11)

- Installed version and build number in Settings, with the target version when an update is available.
- An explicit result after each manual update check; installation is not offered from cached data when the check fails.
- Both installed and available versions in weekly update notifications.

- Battery time estimates until empty or fully charged, displayed inside the popover.
- Expandable battery details with the reported power-adapter wattage.
- Connected accessory battery readings, including separate AirPods components when macOS reports them. Disconnected cached readings are excluded.
- Expandable network details: Wi-Fi signal, band, channel, local IPv4 address, and address copying.
- Audio-output selection with persistent favorites and optional default-microphone selection.
- Configurable low-battery notifications at 10%, 20%, or 30%, with optional sound. Notifications are off by default and require system authorization.
- Independent visibility settings for menu sections and battery time. Expanded content scrolls when necessary.
- Original DuoBar battery ring, volume controls, color coding, and menu-bar behavior retained.

## Experimental DMG

[Download T-DuoBar 1.6.1](https://github.com/squazaryu/T-DuoBar/releases/download/v1.6.1/T-DuoBar-1.6.1.dmg) · [Release notes and SHA-256](https://github.com/squazaryu/T-DuoBar/releases/tag/v1.6.1)

**The DMG is an experimental ad-hoc signed build, not Developer ID signed or Apple notarized.** Quit DuoBar, back up the installed copy, mount the DMG, and drag `DuoBar.app` to Applications. Launch it from Applications. macOS may block a downloaded copy; use [Apple's documented individual-app procedure](https://support.apple.com/en-us/102445) only if you trust the release. Do not disable system protections globally.

## Build and install

Requires macOS 13 or newer and full Xcode. This version has been built and tested on Apple Silicon; compatibility with every supported macOS version and accessory has not been physically verified.

```sh
git clone https://github.com/squazaryu/T-DuoBar.git
cd T-DuoBar
./script/build_and_run.sh --verify
```

The script builds Release, verifies the local signature, installs `/Applications/DuoBar.app`, and checks that the process runs from that location. It moves any previous installed copy intact to `~/Library/Application Support/T-DuoBar/Backups/`.

**This fork does not yet provide a Developer ID signed and notarized download.** The experimental DMG and local builds use ad-hoc signing. The application retains the DuoBar name and bundle identifier, shares its preferences, and replaces the installed DuoBar copy; the fork and original are not intended to run simultaneously. See [DEVELOPMENT.md](DEVELOPMENT.md) for test and debugging commands.

## Validation and limitations

The 1.6.1 implementation passed 273 tests; six hardware-dependent tests were skipped. These results do not replace testing on your devices.

- Battery duration is the estimate supplied by macOS and may be unavailable.
- Accessory support and individual earbud/case readings depend on the macOS Bluetooth report. Reads occur locally while the accessory section is shown.
- A reliable public source for the charge limit has not been identified, so it remains **Unavailable**. The app does not infer a limit from an 80% reading or a paused charge.
- Adapter wattage is the reported adapter rating, not a measurement of charging power.
- Wi-Fi details can be withheld by macOS permissions. Device-managed volume may not be adjustable.
- Low-battery notifications fire on a threshold crossing, not simply on startup below the threshold.

System-status processing is local. The updater makes an HTTPS request to this project’s Homebrew version manifest; it does not upload system-status data. There is no backend, tracking, or system-status upload. Selecting a microphone changes the default Core Audio input; the app does not record audio.

## Upstream and license

Based on upstream `main` at `83522010048124876c2e54c8232ad31d1920577c`. Historical marketing files and release notes retained in this repository describe the original project, not a signed release of this fork.

DuoBar was created by Mike Li / Mikeli7666. Original copyright and the [MIT license](LICENSE) are preserved. T-DuoBar is an independent community fork and is not affiliated with Apple.
