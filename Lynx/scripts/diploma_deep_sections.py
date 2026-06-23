# -*- coding: utf-8 -*-
"""Развёрнутые уникальные абзацы по разделам диплома Lynx."""

DEEP: dict[str, list[str]] = {
    "1.1.1": [
        "Спрайт в Lynx описывается полями texturePath, pivot, scale и uv_rect. Поле uv_rect "
        "пересчитывается ядром на каждом кадре анимации и передаётся клиенту — именно "
        "расхождение uv_rect между SceneEditor и GamePlayerScreen является блокирующим "
        "дефектом волны 0.",
        "Тайлмап в формате v3 состоит из слоёв TilemapLayerData; каждый слой ссылается "
        "на tilesetId из project.json. Редактор рисует слой через tilemap_layer_painter; "
        "ядро при коллизии читает поле collision в чанке, а не только визуальный tile_id.",
    ],
    "1.1.2": [
        "В Lynx этап ввода на native: Flutter собирает KeyboardListener и GamepadFeeder, "
        "передаёт состояние в scene_set_keys и scene_set_gamepad до вызова scene_update. "
        "Так Lua-скрипт видит актуальные key_a и gp_a в том же кадре, что и физика.",
        "Этап рендера: GameWorldPainter получает список объектов с уже вычисленными "
        "позициями и uv_rect; сортировка по sorting_layer и z гарантирует, что задний "
        "план тайлмапа не перекрывает героя на переднем слое.",
        "Ограничение dt: GamePlayerScreen передаёт в scene_update минимум из реального "
        "интервала и 1/30 с, чтобы при просадке FPS не «проскакивать» коллизии тайлов.",
    ],
    "1.1.3": [
        "Демонстрационный проект platformer-wave2 содержит сцены menu и level; переход "
        "реализован скриптом menu.lua с вызовом load_scene при нажатии Enter. Autoload "
        "не требуется для меню, но HUD может подключаться через autoloadSceneIds в "
        "project.json для параллельной разработки интерфейса и уровня.",
        "Экспорт preset all формирует три каталога dist/windows, dist/web, dist/android "
        "с идентичным game_data — это прямая иллюстрация параллельной поставки из темы "
        "диплома без дублирования контента вручную.",
    ],
    "1.2.1": [
        "Контракт FFI включает функции scene_create, scene_update, scene_destroy, "
        "scene_set_paused, scene_set_gamepad. Указатель сцены хранится в Dart как int; "
        "при смене сцены обязателен scene_destroy — иначе утечка native-памяти при "
        "переходе menu → level в platformer-wave2.",
        "Сериализатор scene_to_engine_json преобразует Dart Scene в JSON, совместимый "
        "с десериализатором Rust. Roundtrip-тест в cargo test гарантирует, что поля "
        "behavior_tree и platformerMotor не теряются при экспорте из редактора.",
    ],
    "1.2.2": [
        "Coyote time в PlatformerMotor задаётся числом кадров: пока счётчик больше нуля "
        "после схода с земли, прыжок разрешён. Jump buffer запоминает key_space на "
        "несколько кадров до приземления — типичные значения 5–8 кадров при 60 FPS.",
        "Узел leaf_chase_x в BT задаёт преследование по горизонтали к цели с id из "
        "properties; leaf_wait — задержка в секундах; inverter меняет успех на неудачу "
        "для построения условий «пока не на земле».",
        "Событие footstep в AnimationClip: массив events с полями frame, type signal, "
        "name footstep. При переходе EntityAnimator на кадр N ядро эмитит сигнал в "
        "очередь; клиент в GamePlayerScreen воспроизводит WAV из assets/audio.",
    ],
    "1.2.3": [
        "Поле formatVersion: 3 в корне JSON сцены обязательно; редактор отказывает в "
        "сохранении при несовместимой версии. Поле extensions — массив плагинов с "
        "type и config для LynxPluginHost.",
        "project.json для platformer-demo задаёт inputMap: move_left → KeyA, jump → Space; "
        "эти коды попадают в Lua как key_a и key_space после маппинга в ядре.",
    ],
    "2.1.1": [
        "Граница продукта Lynx на защите диплома: показать работающий platformer-demo "
        "в редакторе и Play, экспорт ZIP, веб-страницу и APK из одной команды, "
        "регрессию волны 0 зелёной на чистой машине.",
        "Вне границ: коммерческий магазин ассетов, полноценный 3D-конвейер lynx-core "
        "scene3d, продакшен-биллинг как основной результат — только задел в ER-модели.",
    ],
    "2.1.2": [
        "Сценарий преподавателя на защите: открыть Hub → platformer-demo → Play 60 с → "
        "сверить UV героя с редактором → запустить автоматизированный сценарий регрессии "
        "волны 0 → показать таблицу 8 ручных сценариев с отметкой pass.",
        "Сценарий студента-автора: скопировать шаблон проекта, изменить tile_ids в "
        "main.json, добавить leaf_patrol врагу через инспектор BT JSON, экспортировать "
        "preset web и открыть в Chrome без установки Flutter.",
    ],
    "2.2.4": [
        "Рисунок 3 (последовательность Play): (1) GamePlayLoader.load; (2) merge autoload; "
        "(3) scene_to_engine_json; (4) scene_create; (5) Ticker 60 Гц; (6) scene_update(dt); "
        "(7) read positions + uv_rect; (8) GameWorldPainter.paint.",
        "При паузе scene_set_paused(true) ядро пропускает интеграцию, но клиент продолжает "
        "рисовать последний кадр — UX паузы без чёрного экрана.",
    ],
    "2.3.2": [
        "Autotile в редакторе: при рисовании кистью анализируются четыре соседа в tile_ids "
        "и подставляется индекс из набора autotile для tileset. Коллизия в том же чанке "
        "получает тип из выбранной кисти (0–4), а не из визуального индекса тайла.",
        "RoomZone в main.json задаёт прямоугольник в мировых координатах; Camera2D после "
        "follow клампит центр в [camera_min, camera_max] комнаты, в которой находится "
        "цель камеры (обычно Player).",
    ],
    "2.4.1": [
        "Инспектор объекта в SceneEditor показывает поля transform, layerId, scriptPath "
        "и вложенный JSON для platformerMotor, animStateMachine, rustBehaviorTree. "
        "Редактирование BT — текстовое поле JSON (волна 10 добавляет overlay в Play, "
        "но не визуальный граф-редактор).",
        "Панель «Тайлы»: выбор tilesetId, режим кисти collision type, кнопка autotile. "
        "Холст масштабируется с сохранением пиксельной сетки чанка tw×th.",
    ],
    "2.4.2": [
        "GamePlayerScreen оборачивает GameWorldPainter в AspectRatio из designWidth и "
        "designHeight проекта. Фон #0d1117 скрывает letterbox при несовпадении "
        "соотношения сторон монитора и 16:9 дизайна 960×540.",
        "Overlay BT active рисуется поверх кадра списком узлов с подсветкой текущего "
        "leaf; breakpoint срабатывает при совпадении подстроки в debug_path — удобно "
        "для отладки PatrolEnemy без остановки симуляции.",
    ],
    "2.5.2": [
        "engine_bridge.dart объявляет внешние функции через dart:ffi DynamicLibrary.open "
        "для Windows. На Android — libengine.so; на Web библиотека не грузится, "
        "вместо неё создаётся WebSceneEngine.",
        "После scene_update клиент читает JSON-ответ или бинарный буфер позиций — "
        "в дипломной сборке приоритет у uv_rect из ядра, локальный AnimSM на Dart "
        "отключён при активном FFI для соблюдения волны 0.",
    ],
    "2.6.1": [
        "Волна 3 (не детализирована в таблице 10) — улучшения редактора; волна 5–8 — "
        "промежуточные инкременты камеры, комнат, аудио. Для диплома критичны волны "
        "0, 2, 4, 9, 10, 11 как несущие FR из таблицы 1.",
        "Падение регрессии волны 11 указывает на расхождение WebSceneEngine и native FFI — "
        "типичная причина: отсутствие coyote в Dart-фолбэке или иной порядок сортировки.",
    ],
    "3.1.1": [
        "Уровень L1 (unit Rust): тесты platformer.rs на TILE_ONE_WAY снизу вверх и "
        "сверху вниз. Уровень L2 (unit Dart): codec scene v3, merge autoload. "
        "Уровень L3 (FFI): интеграционный тест scene_create + 10× scene_update. "
        "Уровень L4 (E2E): ручные сценарии таблицы 8.",
        "Блокер альфы: любой fail в волне 0 или расхождение UV по скриншоту. "
        "Major: падение export web. Minor: косметика UI редактора на <840 px.",
    ],
    "3.2.1": [
        "Измерение 4 мс: логирование длительности scene_update в debug-сборке engine; "
        "среднее за 300 кадров на platformer-demo при 1080p не должно превышать норматив. "
        "8 мс paint: Flutter Timeline в DevTools для GameWorldPainter.",
        "cargo test --package engine behavior_tree: проверка debug_path содержит leaf_patrol "
        "после трёх тиков PatrolEnemy. flutter test test/wave0_platformer_demo_test.dart: "
        "сравнение uv_rect[0] и uv_rect[1] с допуском 0.001.",
    ],
    "1.1.4": [
        "Связь FR-03 с реализацией: типы коллизий 0–4 соответствуют константам TILE_* "
        "в platformer.rs; autotile — только визуальный слой tile_ids, collision хранится "
        "отдельно в чанке.",
        "FR-06 проверяется на platformer-wave2: load_scene из menu.lua, без перезапуска "
        "приложения; указатель FFI пересоздаётся через scene_destroy в GamePlayLoader.",
    ],
    "1.3.1": [
        "Unity Animator Controller аналогичен AnimStateMachine Lynx, но хранится в "
        "бинарном .controller; в Lynx переходы idle→run описаны в JSON properties и "
        "видны в Git diff — плюс для учебной ревизии кода диплома.",
    ],
    "1.3.2": [
        "Godot TileMapLayer близок к TilemapLayerData Lynx, но чанки в Godot внутренние; "
        "в Lynx cx, cy, tw, th явно в JSON — проще писать автотесты на размер чанка.",
    ],
    "1.4.1": [
        "Склон 45° в Lynx смещает позицию объекта при контакте по нормали склона — "
        "упрощённая модель без физического тела наклона; достаточна для учебного "
        "платформера, не претендует на полный паритет Sonic.",
    ],
    "1.4.2": [
        "Overlay BT в Play не останавливает игру — debug_path обновляется каждый кадр; "
        "breakpoint по подстроке пути позволяет «остановить внимание» на leaf_patrol "
        "без debugger Rust.",
    ],
    "1.4.3": [
        "WebSceneEngine может не укладываться в 4 мс — Dart-интерпретатор; норматив "
        "4 мс формально относится к native FFI; для Web фиксируется отдельный "
        "практический потолок 8 мс на полный кадр в браузере.",
    ],
    "1.3.5": [
        "По критерию «регрессия волн 0–11» Lynx единственный в таблице 2 с "
        "автоматизированными сценариями на каждый инкремент; Unity и Godot полагаются "
        "на ручной QA или сторонние CI-плагины.",
    ],
    "2.2.2": [
        "Атрибут content_json в scene_versions хранит полный JSON сцены v3 для отката "
        "и diff между ревизиями; локальный аналог — коммит Git в scenes/main.json.",
        "Tileset в project.json: id, texturePath, tileWidth, tileHeight, columns — "
        "связь N:1 с TilemapLayerData.tilesetId; без валидного tileset редактор "
        "не рисует кисть на холсте.",
    ],
    "2.2.1": [
        "Диаграмма компонентов (рисунок 1): верхний блок — EngineMainPage, SceneEditor, "
        "GamePlayerScreen, GameWorldPainter, tilemap_layer_painter; средний — "
        "engine_bridge, scene_to_engine_json, GamePlayLoader; нижний — scene.rs, "
        "platformer.rs, behavior_tree.rs, lua.rs; перспектива — lynx-core batch2d.",
    ],
    "2.2.3": [
        "Подсистема экспорта: скрипт export-player с аргументами --preset и --project-dir; "
        "копирует game_data и подставляет собранный client. Не входит в Rust — "
        "отдельный контур сборки для параллельных артефактов.",
    ],
    "2.3.1": [
        "Поле z объекта задаёт order_in_layer внутри SceneLayer; sorting_layer берётся "
        "из sortOrder слоя. Герой platformer-demo на слое «Entities» с z=10, тайлмап "
        "фона — слой «Background» с меньшим sortOrder.",
    ],
    "2.3.3": [
        "Локальный путь projects/platformer-demo/scenes/main.json — единственный "
        "источник уровня для волны 0; Git diff по main.json используется в учебных "
        "заданиях «добавить one-way платформу в секции 3 уровня».",
    ],
    "2.4.3": [
        "NexusGamepadFeeder опрашивает пакет gamepads, нормализует оси в [-1,1] и "
        "вызывает scene_set_gamepad перед тиком. На Web геймпад через Flutter "
        "Gamepad API с тем же контрактом gp_lx.",
    ],
    "2.5.1": [
        "PhysicsBody на объекте с one_way=true позволяет стоять сверху другой сущности "
        "и проваливаться при нажатии вниз+прыжок — дополнение к тайловым one-way.",
        "Очередь звука сцены: play_sound_bus в Lua кладёт запись {path, bus, volume}; "
        "после update клиент опрашивает очередь и применяет audioBusVolumes из project.json.",
    ],
    "2.5.3": [
        "Структура ZIP windows: Player.exe, engine.dll, game_data/project.json, "
        "game_data/scenes/*.json, game_data/assets/**. Запуск без установки Flutter — "
        "критерий приёмки FR-07 для преподавателя без dev-окружения.",
    ],
    "2.6.2": [
        "CRDT в клиенте (задел): операции над properties объекта мержатся по "
        "ламport-часам; при облачной синхронизации scene_versions хранит полный "
        "content_json каждой ревизии для отката.",
    ],
    "2.6.3": [
        "Тест lynx-core batch2d: упаковка четырёх квадов в один draw batch с общим "
        "texture id. Не интегрирован в GameWorldPainter дипломной сборки — "
        "зафиксировано как направление M2→M3 интеграции.",
    ],
    "3.4.1": [
        "Итоговая оценка альфы: 7 волн регрессии из таблицы 11 — pass; 10 ручных "
        "сценариев — pass на Windows 11; Web — pass с оговоркой упрощённой Lua; "
        "Android APK — pass на эмуляторе API 33.",
    ],
    "3.3.1": [
        "Сценарий 4 (BT враг): открыть platformer-demo, Play, включить в меню overlay "
        "BT, убедиться что у PatrolEnemy подсвечен leaf_patrol. Сценарий 5: platformer-wave2, "
        "на menu нажать Enter, загрузилась level без crash и без утечки (повторить 10 раз).",
        "Сценарий 7 (Export Web): открыть dist/web/index.html в Chrome, Play 30 с, "
        "герой двигается от клавиатуры; ожидание: упрощённая физика WebSceneEngine, "
        "но загрузка сцены без ошибок консоли.",
    ],
}
