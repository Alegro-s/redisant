# Nexus Launcher и Nexus Editor

- **Nexus Launcher** — точка входа по умолчанию: `lib/main.dart` (`flutter run`). Управление проектами, новости (RSS), магазин (JSON), запуск редактора.
- **Nexus Editor** — отдельная сборка с тем же Rust FFI: `flutter run -t lib/main_editor.dart` или `flutter build windows -t lib/main_editor.dart`.

## Аргументы редактора (облако + локальный движок)

Двоичный движок подтягивается как и раньше (`EngineInstallHub`). Проект из облака:

```text
nexus_editor.exe --project-id=<uuid> --project-name="Имя" --api-base=http://host:8080 [--cloud-read-only]
```

Launcher при включённой опции «отдельным процессом» передаёт эти аргументы автоматически.
