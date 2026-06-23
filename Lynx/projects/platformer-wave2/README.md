# Platformer Demo (Lynx Wave 0)

Эталонный проект для регрессии **волны 0**: Play на Windows должен совпадать с редактором (тайлмап из атласа, анимация героя, платформер).

## Быстрый старт

```powershell
# Из корня Lynx
python scripts/generate_wave0_demo_assets.py
scripts/run-wave0-regression.ps1
```

В редакторе: **Файл → открыть проект** → эта папка → сцена `main` → Play.

## Содержимое

| Путь | Назначение |
|------|------------|
| `project.json` | Тайлсет `platform`, размер 960×540 |
| `scenes/main.json` | Уровень, игрок, камера, motor + anim SM |
| `assets/tilesets/platform.png` | 4 тайла 32×32 |
| `assets/sprites/hero.png` | 2 кадра бега |
| `assets/scripts/player.lua` | WASD + прыжок |

## Регрессия

```powershell
D:\PO\Lynx\scripts\run-wave0-regression.ps1
```

См. также [docs/ROADMAP_WAVES.md](../../docs/ROADMAP_WAVES.md).
