# T-DuoBar 1.6.1 — update results and version information

**Experimental community build, ad-hoc signed and not Apple notarized.** Universal 2 for Apple Silicon and Intel, macOS 13+; build 11. Runtime validation is on Apple Silicon, not Intel.

## Changes

- Settings always show the installed version and build number, plus the available version when an update exists.
- Every manual update check shows a result: an installation offer, confirmation that the installed version is current, or a connection error.
- Update dialogs and weekly notifications identify both installed and available versions, including build numbers.
- A failed manual check no longer offers installation based on an old cached result.

No breaking changes or migrations. Existing preferences are retained. Weekly checks still notify only when a new version is available; manual-check dialogs do not require macOS notification permission.

## Install or update

```sh
brew install --cask squazaryu/tap/t-duobar
```

For an existing Homebrew installation, use **Install with Homebrew** in DuoBar or:

```sh
brew update
brew upgrade --cask squazaryu/tap/t-duobar
```

Quit DuoBar before updating from Terminal, then reopen it. The in-app script handles quitting and reopening automatically. Before the first Homebrew install, back up a manually installed `/Applications/DuoBar.app`; do not discard it with `--force`.

## Validation and distribution limits

273 tests passed; six hardware-dependent tests were skipped. Both compiled architectures, the DMG checksum, the copied app signature, and local startup from the package were verified. Dialog and notification text is covered by automated tests; live notification delivery depends on macOS permission and a newer release.

Homebrew checks the DMG's SHA-256; it does not provide Developer ID or notarization. Normal Gatekeeper acceptance of Internet-downloaded builds has not been validated. macOS may require individual approval; see [Apple's instructions](https://support.apple.com/en-us/102445).

Hardware-dependent accessory readings and the unavailable charge-limit readout are unchanged. The checker reads only the public Homebrew manifest and uploads no system-status data.

---

В настройках теперь постоянно видны установленная версия и номер сборки. Ручная проверка сообщает, есть ли обновление, до какой версии оно доступно или что установленная версия актуальна. Окна и системные уведомления содержат оба номера. При ошибке проверки установка по старым данным из кэша больше не предлагается. Миграций нет, настройки сохраняются.

## SHA-256

```text
ae280c1649fd685d6481d4b2ff5c49175c8ac63f9dd740608357010bbf19896b  T-DuoBar-1.6.1.dmg
```
