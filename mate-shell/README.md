# MateShell

**DeX-подобная оболочка для Huawei MatePad 11** с локальным Linux (Termux + proot Debian + XFCE + VS Code). Всё работает на планшете, без code-server и без Steam Link.

## Что это даёт

| Возможность | Как |
|-------------|-----|
| Рабочий стол с панелью задач | MateShell `DesktopActivity` |
| Настоящий Linux (Debian) | Termux + `proot-distro` |
| VS Code локально | `.deb` ARM64 внутри Debian |
| Git, Node, npm, Firefox | В Debian |
| Терминал | Termux или XFCE Terminal |
| Steam | **Android-версия** (не PC Steam) |

## Честные ограничения

- **PC Steam в Linux на ARM не запустится** — нет x86, нет нормального GPU для Proton. Иконка Steam открывает **Steam для Android** (AppGallery/APK).
- **VS Code** — полноценный desktop ARM, но тяжёлый; первый запуск медленный.
- **Не Samsung DeX** — это своя оболочка + Linux в proot, не замена Windows.
- **Huawei без GMS** — Termux только с **F-Droid**, не из Play Store.

## Установка на MatePad 11

### 1. Termux (F-Droid)

1. Скачайте [Termux с F-Droid](https://f-droid.org/packages/com.termux/).
2. Откройте Termux → **Settings** → включите **Allow external apps**.

### 2. MateShell APK

Соберите на ПК или установите готовый APK:

```bash
cd mate-shell
./gradlew assembleDebug
# APK: app/build/outputs/apk/debug/app-debug.apk
```

Скопируйте APK на планшет и установите.

### 3. Первый запуск

1. Откройте **MateShell** (лучше в **ландшафте** + клавиатура/мышь по USB/BT).
2. **Setup** → «Установить Linux» (~2 GB, Wi-Fi, 10–30 мин).
3. Прогресс: в Termux `tail -f ~/mate-shell/install.log`
4. После установки: **Linux** → откроется XFCE через noVNC на `127.0.0.1`.
5. В XFCE: меню → **code** или терминал → `code .`

Пароль VNC по умолчанию: `mateshell` (сменить: `vncpasswd` в Debian).

### 4. Сделать MateShell «домашним экраном» (опционально)

При первом нажатии Home выберите MateShell → «Всегда».

## Структура

```
mate-shell/
├── app/src/main/java/io/mateshell/
│   ├── DesktopActivity.java      # рабочий стол + taskbar
│   ├── LinuxDesktopActivity.java # noVNC → XFCE
│   ├── SetupActivity.java        # мастер установки
│   ├── TermuxHelper.java         # RUN_COMMAND API
│   └── LinuxService.java         # старт/стоп VNC
└── app/src/main/assets/
    └── install-linux.sh          # Debian + XFCE + VS Code
```

## Ручной запуск (Termux)

```bash
bash ~/mate-shell/start-linux.sh   # VNC + noVNC :6080
bash ~/mate-shell/stop-linux.sh
```

## Сборка

- Android Studio или JDK 17 + Android SDK 34
- `minSdk 26`, `targetSdk 34`

## Лицензия

MIT — используйте на свой риск; proot/Termux — отдельные лицензии.
