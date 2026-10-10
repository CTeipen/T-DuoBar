# T-DuoBar 1.5.0 — experimental DMG

**Community fork of [DuoBar](https://github.com/Mikeli7666/DuoBar). This download is ad-hoc signed, NOT Developer ID signed or Apple notarized.** GitHub marks it as a pre-release because of these distribution limitations.

## Download and installation

- `T-DuoBar-1.5.0.dmg`: Universal 2, arm64 + x86_64; macOS 13+.
- `SHA256SUMS`: SHA-256 checksum for the DMG.
- Quit DuoBar, keep a backup of the installed app, and drag `DuoBar.app` from the image to Applications.
- The app retains the original name and bundle identifier, replaces the installed DuoBar, and shares preferences. It does not create a separate Dock window.
- macOS may block an Internet-downloaded copy. If you trust the release, follow [Apple's documented per-app procedure](https://support.apple.com/en-us/102445). Do not disable Gatekeeper or SIP globally.

## Features

- Battery time estimates and expandable power-adapter details.
- Connected accessory batteries; disconnected cached readings excluded.
- Wi-Fi details and local IPv4 copying.
- Favorite audio outputs, optional microphone selection, configurable menu sections.
- Opt-in low-battery notifications at 10%, 20%, or 30%.

## Validation and limitations

The implementation passed 262 local tests; six hardware-dependent tests were skipped. Both architectures were compiled; runtime validation is on Apple Silicon, not Intel. Disk-image verification, app-signature integrity, mounted-image copy, and startup were checked before publication. Acceptance of Internet-quarantined downloads under standard Gatekeeper policy has not been validated.

Battery/accessory readings depend on macOS and hardware support. The charge-limit readout remains unavailable. Adapter wattage is a reported rating, not a measurement. System-status data stays local.

No source-schema migration is required. Existing app preferences are retained. The installation replaces the old app; preserving that copy is the user's responsibility when installing by drag and drop.

---

Экспериментальная сборка T-DuoBar 1.5.0, build 8. **Без Developer ID и notarization.** В комплекте инструкции установки на русском и английском. Перед заменой завершите DuoBar и сохраните старую копию. Если macOS заблокирует запуск, используйте инструкцию Apple выше для разрешения отдельного приложения, только если доверяете этой сборке.

## SHA-256

```text
ac9cd3e3a602c624fa3b786b5ebd0463d448a9a205429f326523f06795fadf41  T-DuoBar-1.5.0.dmg
```
