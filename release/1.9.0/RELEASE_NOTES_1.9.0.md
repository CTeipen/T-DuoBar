# T-DuoBar 1.9.0 — settings, status and stability

**Experimental community build, ad-hoc signed and not Apple notarized.** Build 18; Universal 2 for Apple Silicon and Intel, macOS 13+. Runtime testing was on Apple Silicon.

## What's new

- Native General, Notifications and Updates settings tabs, plus a right-click menu for settings, update checks and quitting.
- Saved section order: drag the handles or use Move up / Move down. Visibility settings are independent of order.
- Battery hover tooltip with charge, power state and the current time estimate, using existing readings.
- Quick System Settings links and explanations for unavailable network, battery, audio and accessory data.
- A Personal Hotspot chain symbol for Wi-Fi that macOS marks as expensive.
- A distinct T-DuoBar app icon and native About panel with version, build, credits and project links.

## Fixes

- Closing the popover cancels and reaps its accessory-reading helper. Late results cannot overwrite a reopened menu; hidden views do not start polling. Timer tolerances allow macOS to coalesce background wakeups.
- System Settings buttons stay inside aligned cards. The empty accessory state is a compact row.
- The power bolt clears the ring and stays in place while fading out. The center glyph makes room while the bolt is shown.
- The title stays at the top during disclosure height changes. Hover popovers are suppressed while the context menu is open.

No breaking changes or migration steps. Existing preferences, the `DuoBar.app` filename and the original bundle identifier are retained. No global keyboard shortcut was added.

## Install or update

```sh
brew install --cask squazaryu/tap/t-duobar
```

For an existing Homebrew installation, use the app's **Install with Homebrew** action or:

```sh
brew update
brew upgrade --cask squazaryu/tap/t-duobar
```

Quit DuoBar before updating from Terminal and reopen it afterward. The bundled in-app script handles quitting and reopening. Back up a manually installed copy before the first Homebrew install; do not discard it with `--force`.

## Validation and limits

311 tests passed; six hardware-dependent checks were skipped. Release compiled for both architectures. The DMG checksum, mounted/copied app signature and packaged-app startup were verified. Regression tests reproduced the bolt overlap and title displacement before their fixes. These results do not establish Intel runtime support, every supported macOS/device combination or long-duration energy measurements. Native move commands and order persistence were checked; direct drag completion and every System Settings landing page still need broader manual testing.

Hotspot detection is a metered-Wi-Fi presentation heuristic based on the system's expensive-path flag, not device identification. An unmarked phone keeps the regular Wi-Fi symbol; another metered Wi-Fi network may use the chain. No SSID-name guessing or nearby-network scan is used. Battery estimates and accessory/component readings depend on macOS; the charge limit remains unavailable.

Homebrew verifies SHA-256 but does not supply Developer ID or notarization. Internet-downloaded builds may require individual approval under [Apple's documented procedure](https://support.apple.com/en-us/102445). Normal Gatekeeper acceptance has not been established; do not disable system protections globally.

---

## По-русски

Настройки разделены на три вкладки. Правый клик открывает настройки, проверку обновлений и выход. Порядок разделов сохраняется; менять его можно перетаскиванием или командами «Выше/ниже». Добавлены подсказка батареи, переходы в системные настройки, пояснения недоступных показаний, иконка точки доступа и собственный облик T-DuoBar с окном «О приложении».

Исправлены отмена чтения аксессуаров, положение кнопок карточек, наложение молнии на кольцо и смещение заголовка при раскрытии подробностей. Пустой блок аксессуаров стал компактным. Новые фоновые таймеры для подсказки и точки доступа не добавлены.

Настройки сохраняются, миграций и breaking changes нет. Для обновления через Homebrew используйте команды выше или кнопку установки в приложении. Сборка экспериментальная, без Developer ID и notarization. Прошли 311 тестов, шесть аппаратных проверок пропущены; Intel проверен сборкой, физические проверки всех устройств и версий macOS не выполнены.

## SHA-256

```text
4686cb542466b1425196898f6a8522920d4a656beb56866134eea28a41edaf9a  T-DuoBar-1.9.0.dmg
```
