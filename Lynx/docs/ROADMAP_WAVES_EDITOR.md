# Lynx Editor — дорожная карта волн

План доработки редактора, Launcher и движка после аудита UX (июнь 2026).

## Wave 0 — критические исправления (✅)

- **Play / вкладка «Игра»**: `resolvePlayEngineLibrary()` + установленный `.lynxengine` из `%LOCALAPPDATA%\Lynx\engines\`
- **Холст сцены**: pan (ЛКМ по пустому, ПКМ, тачпад/scroll), zoom (pinch, Ctrl+scroll)
- **Перемещение объектов**: drag с учётом transform viewport
- **Sidebar «Все / Спрайты / …»**: фильтр проводника на mobile + chips
- **Брендинг**: nexUs → Lynx; убран диалог «ограничения Unity»
- **Mobile landscape**: split-layout (sidebar + сцена + inspector), без bottom nav

## Wave 1 — тема и типографика (✅)

- Шрифт **Montserrat** (Launcher + Editor)
- Три темы: **фиолетовая тёмная**, **серая (midnight)**, **светлая** (белая + чёрные акценты)
- Единые размеры кнопок sidebar / toolbar, без переносов «Поделиться» / «Выход»

## Wave 2 — Launcher UX (✅)

- Hub: быстрые действия «Engine / Проекты / Импорт ZIP / Редактор»
- Inline-баннер «Lynx Engine не установлен» без modal spam
- **Горячие клавиши редактора** — см. `Ctrl+/` или F1 в Lynx Editor

## Wave 3 — редактор «как у больших» (✅)

- **LynxScript / Blueprint**: кнопка в ScriptEditor и Inspector, `Ctrl+Shift+B`, sidecar `.graph.json`
- **Звук**: панель предпросмотра в sidebar, импорт через меню ⋮
- **Комнаты / сцены**: вкладки холстов над сценой, «+» новая сцена, зоны → `targetSceneId`
- **Sprite editor**: кисти / undo per stroke — отложено в Wave 5

## Wave 4 — эталонный проект Tetris (✅)

- `projects/tetris-demo/` — импортируемый проект
- Шаблон **Tetris** в Launcher MSI
- Отрисовка `logic_grids` в GameWorldPainter

## Wave 5 — polish & release (✅)

- CI: `.github/workflows/lynx-editor-smoke.yml` — pack/import, embedded pack, wave5 tests
- Документация: [PRODUCT_ARCHITECTURE.md](PRODUCT_ARCHITECTURE.md), [FIRST_PROJECT.md](FIRST_PROJECT.md)
- Hub → **Tetris demo** → экспорт `.lynxproject`
- Sprite editor: undo per stroke, кисти 1–4, корректный hit-test на non-square grid, экспорт PNG

---

### Как проверить Wave 5

1. Hub → **Tetris demo** → сохранить `.lynxproject` → **Импорт ZIP** → F5
2. Sprite Editor: кисть 2×2, undo одним штрихом, **Экспорт PNG**
3. `cd Lynx\scripts; .\run-wave5-regression.ps1`

---

### Как проверить Wave 3

1. Открыть проект → вкладки **Холсты** над сценой, создать вторую сцену
2. Sidebar **Звук** → импорт WAV → **Прослушать** справа
3. Скрипт → **Blueprint** или `Ctrl+Shift+B` → сохранить LynxScript
4. Меню ⋮ → **Комнаты камеры** → привязать зону к сцене-холсту
