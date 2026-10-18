# T-DuoBar 1.10.0 — language and menu refinements

Build 22 · Universal 2 (Apple Silicon and Intel) · macOS 13+.
Experimental community build with an ad-hoc signature; not Developer ID signed or Apple notarized.

## Что нового

- Выбор языка приложения без перезапуска: язык системы, английский, русский, украинский, упрощённый или традиционный китайский.
- Настройка скрытия пустого раздела аксессуаров. Подключённые устройства появляются автоматически; ошибки чтения остаются видны.
- Управление громкостью прокруткой по значку в строке меню. Учитываются направление прокрутки и точные движения трекпада; инерция игнорируется.
- Проценты батареи и громкости теперь рядом с названиями, на общей базовой линии. Слайдер использует доступную ширину строки.
- Исправлена область нажатия раскрывающихся карточек: пустое место между текстом и стрелкой тоже открывает подробности. Кнопка системных настроек работает отдельно.

Скрытие пустого раздела и прокрутка громкости по умолчанию выключены. Язык по умолчанию следует системе. Несовместимых изменений и миграций нет; прежние настройки, имя `DuoBar.app` и bundle identifier сохранены.

## Установка и обновление / Install and update

```sh
brew install --cask squazaryu/tap/t-duobar
```

Для установленной через Homebrew версии / For an existing Homebrew installation:

```sh
brew update
brew upgrade --cask squazaryu/tap/t-duobar
```

Также можно нажать «Установить через Homebrew» в приложении. Скрипт завершит приложение, обновит и запустит его снова. При обновлении вручную через Terminal завершите DuoBar перед командой и откройте после неё. Перед первой установкой через Homebrew сохраните установленную вручную копию.

## Checks and limitations

320 tests passed; six hardware-dependent checks were skipped. Release compiled for both architectures; runtime tests ran on Apple Silicon. A native hosted interaction regression first reproduces the blank-space disclosure bug, then verifies opening/closing and the independent Settings action. Language switching and the new switches were checked in native settings. Physical scroll gestures over the installed status item, every accessory/macOS combination and long-duration energy use have not been fully validated.

Homebrew verifies the DMG's SHA-256; it does not add Apple notarization. Internet-downloaded copies may require individual approval using [Apple's documented procedure](https://support.apple.com/en-us/102445). No system protections need to be disabled.

## English

Select the app language without restarting, optionally hide empty accessory results, and optionally adjust volume by scrolling over the menu-bar icon. Both optional behavior switches default to off; language follows the system by default. Volume and battery values now sit beside their titles, and the slider uses the available width. Disclosure headers accept clicks in the blank gap before the chevron while System Settings keeps its separate action.

No breaking changes or migration steps. Existing preferences, the app filename and bundle identifier are retained. Use the in-app Homebrew action to quit, update and reopen automatically, or quit DuoBar before a manual Terminal upgrade and reopen afterward.
