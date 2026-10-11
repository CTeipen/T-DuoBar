# T-DuoBar 1.6.0 — Homebrew updates

**Experimental community build, ad-hoc signed and not Apple notarized.** Universal 2 for Apple Silicon and Intel, macOS 13+; build 9. Runtime validation is on Apple Silicon, not Intel.

## New in 1.6.0

- Homebrew installation and upgrade through `squazaryu/tap/t-duobar`.
- Weekly version checks while DuoBar is running, with catch-up at startup and wake.
- One notification per new version, subject to macOS notification permission.
- An explicit **Install with Homebrew** action opens Terminal with the bundled script, updates only this cask, and reopens DuoBar. Updates are not installed without a click.
- Settings for weekly checks, a manual check, release notes, and a copyable update command.
- Persistent timestamps/cache and a six-hour retry backoff after network failures.

## Installation and updating

```sh
brew install --cask squazaryu/tap/t-duobar
brew update
brew upgrade --cask squazaryu/tap/t-duobar
```

Before the first Homebrew install, quit and back up a manually installed `/Applications/DuoBar.app`. Homebrew's `--adopt` works only for identical artifacts; do not discard the old app with `--force`. The in-app script can preserve a manual installation when transitioning to Homebrew management. Preferences are retained because the app name and bundle identifier are unchanged.

Checks do not run while DuoBar is closed; missed checks occur on its next launch. If notification permission is denied, the available version remains visible in Settings. If Homebrew is absent, the installer shows instructions instead of installing it automatically.

## Validation and limits

269 tests passed; six hardware-dependent tests were skipped. The DMG, copied app signature, both compiled architectures, and local startup were verified. Normal Gatekeeper acceptance of Internet-downloaded builds has not been validated. macOS may require individual approval; see [Apple's instructions](https://support.apple.com/en-us/102445). No global security protections need to be disabled.

Homebrew verifies the published DMG checksum; it does not provide Developer ID or notarization. Accessory readings remain hardware-dependent and the charge limit remains unavailable. The version checker requests only a public HTTPS manifest and uploads no system-status data.

---

Версия 1.6.0 добавляет установку и обновление через Homebrew. Еженедельная проверка включена по умолчанию и работает при запущенном DuoBar. Кнопка «Установить через Homebrew» открывает Terminal с подготовленным скриптом: он обновляет приложение и запускает его снова. Уведомления требуют разрешения macOS. Эта сборка остаётся экспериментальной, без Developer ID и notarization.

## SHA-256

```text
9d5f96b34b0066770346dc24f8b23ad8bdb0a8405dd31288cffe18c5fd1048d2  T-DuoBar-1.6.0.dmg
```
