# T-DuoBar 1.11.0 — VPN status and Liquid Glass

Build 29 · Universal 2 (Apple Silicon and Intel) · macOS 13+; Liquid Glass requires macOS 26+.
Experimental community build with an ad-hoc signature; not Developer ID signed or Apple notarized.

## Что нового

- Отдельный раздел VPN: состояние и профиль, о которых сообщает macOS, дополнительные сведения об интерфейсе и переход в системные настройки. Раздел можно скрыть и переставить.
- Выбор классического оформления или нативного Liquid Glass с настройкой прозрачности фона. Текст и элементы управления сохраняют обычную непрозрачность. Есть кнопка предпросмотра настоящего меню.
- Классическое оформление включено по умолчанию. Оно также используется на старых macOS и при включённом «Уменьшить прозрачность».
- Исправлено повторное открытие меню тем же кликом: переключение выполняется при начале нажатия. Режим наведения и контекстное меню сохранены.
- VPN сохраняет последнее состояние при повторном открытии; чтение отменяется при закрытии, а старые ответы не заменяют новые.

Несовместимых изменений и миграций нет. Прежние настройки, имя DuoBar.app и bundle identifier сохранены. В старом сохранённом порядке VPN добавляется рядом с сетью. Приложение не включает/отключает VPN и не утверждает, что весь трафик проходит через него.

## Install and update / Установка и обновление

```sh
brew install --cask squazaryu/tap/t-duobar
```

For an existing Homebrew installation / Для установленной через Homebrew версии:

```sh
brew update
brew upgrade --cask squazaryu/tap/t-duobar
```

The in-app Homebrew action quits, updates and reopens DuoBar. For a manual Terminal upgrade, quit DuoBar first and reopen it afterward. Back up a manually installed app before adopting Homebrew management.

## Checks and limitations

352 tests passed, six hardware-dependent checks skipped. Release compiled for both architectures; runtime checks ran on Apple Silicon. The user reports normal repeated-click and ordinary lifecycle behavior. A native production-service harness completed 500 VPN observation/read/stop cycles without observation failures. Short desktop measurements found low app CPU usage; system-wide graphics activity could not be attributed to the app. No battery-drain or energy-efficiency claim is made. See [the validation report](https://github.com/squazaryu/T-DuoBar/blob/v1.11.0/release/1.11.0/VALIDATION.md) for measurements and boundaries.

Only configured VPN connections reported by macOS are shown; a tunnel interface name alone is not proof of VPN connectivity. No real VPN disconnect or forced sleep/wake cycle was performed during the audit. Every device/macOS combination and long-duration resource behavior remain outside completed validation.

Homebrew verifies the DMG SHA-256; it does not add notarization. Internet-downloaded copies may require individual approval using [Apple's documented procedure](https://support.apple.com/en-us/102445). No system protections need to be disabled.

## English

A separate, reorderable VPN status card and optional native Liquid Glass appearance with background transparency. Classic remains the default and the fallback for older macOS or Reduce Transparency. Preview opens the actual menu. The status-button toggle now runs once at mouse-down; VPN observation follows real menu visibility and keeps its last snapshot during revalidation. Existing settings are retained, with no breaking changes or migration steps.
