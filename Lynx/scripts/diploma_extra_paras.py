# -*- coding: utf-8 -*-
"""Дополнительные уникальные абзацы — только факты проекта Lynx."""

EXTRA: dict[str, list[str]] = {
    "1.1.1": [
        "В дипломном проекте Lynx эталонным жанром выбран платформер: демонстрационный "
        "проект platformer-demo закреплён как контрольная точка волны 0 — любое изменение "
        "в анимации или отрисовке тайлов должно сохранять совпадение режима Play и редактора.",
        "Формат сцены третьей версии (поле formatVersion: 3) задаёт набор сущностей, "
        "с которыми работают и Rust-ядро engine, и Flutter-клиент: объекты, тайлмапы, "
        "слои, комнаты, клипы анимации и расширения плагинов.",
    ],
    "1.1.2": [
        "В Lynx на нативных платформах этапы логики, физики, камеры и вычисления uv_rect "
        "выполняются в Rust; ввод, отрисовка Canvas и воспроизведение звука через audioplayers — "
        "во Flutter. Клиент не дублирует физику при активном FFI: источник истины — ядро.",
        "Нормативы производительности для дипломной верификации: шаг scene_update не более "
        "4 мс, отрисовка кадра не более 8 мс при 1080p и 60 FPS; остаток бюджета 16,7 мс "
        "оставлен на аудио и ввод.",
    ],
    "1.1.3": [
        "Параллельный экспорт в Lynx реализован пресетами windows, web, android и all "
        "утилиты пакетного экспорта Player: из одного project.json и каталога scenes "
        "формируются ZIP с native-библиотекой, статическая веб-сборка и APK.",
        "Демонстрационный проект platformer-wave2 иллюстрирует параллельные сцены внутри "
        "одной игры: переход menu → level через менеджер сцен и autoload без перекомпиляции ядра.",
        "Поле Scene.collaboration и CRDT в редакторе закладывают параллельную работу авторов; "
        "конфликт версий при облачной синхронизации обрабатывается через HTTP 409 и перезагрузку сцены.",
    ],
    "1.1.4": [
        "Постановка задачи диплома: спроектировать и реализовать Lynx, в котором автор "
        "параллельно ведёт несколько 2D-проектов и поставляет сборки под Windows, Web "
        "и Android из единого JSON-контракта, при детерминированной симуляции на native "
        "и согласованном Play (критерий волны 0).",
    ],
    "1.2.1": [
        "Архитектура Lynx следует разделению: Rust engine (сцена, физика 2D, Lua, BT, "
        "аниматор, камера, очереди звука) не содержит оконной подсистемы и GPU-рендера; "
        "Flutter client (SceneEditor, GamePlayerScreen, GameWorldPainter) не дублирует "
        "игровую физику при FFI.",
        "Мост engine_bridge и сериализатор scene_to_engine_json передают Dart-модель Scene "
        "в JSON для Rust; обратно клиент читает sprite.uv_rect, позиции и camera_center "
        "после каждого scene_update(dt).",
    ],
    "1.2.2": [
        "В ядре Lynx типы тайловых ячеек: 0 — пусто, 1 — твёрдая, 2 — односторонняя платформа, "
        "3 и 4 — склоны 45°. Коллизии с тайлами разрешаются после интеграции скорости, "
        "до попарного разрешения сущность–сущность.",
        "PlatformerMotor задаёт run_speed, jump_speed, gravity_scale, coyote time и jump buffer "
        "в кадрах; порядок тика: Lua → BT → PatrolAi → мотор → AnimStateMachine → "
        "EntityAnimator → иерархия → физика → тайлы → Camera2D → rooms.",
        "BehaviorTree поддерживает узлы sequence, selector, inverter, leaf_patrol, leaf_wait, "
        "leaf_chase_x, leaf_set_velocity, leaf_idle; в Play доступен overlay BT active "
        "с путём активного узла и breakpoint по подстроке пути.",
    ],
    "1.2.3": [
        "project.json задаёт designWidth 960 и designHeight 540 для platformer-demo, "
        "startupSceneId, inputMap (move_left, jump), audioMasterVolume, tilesets с texturePath. "
        "Autoload-сцены подмешиваются при загрузке Play через GamePlayLoader.",
        "На Web отсутствует полный FFI engine.dll — Play использует WebSceneEngine в Dart "
        "с упрощённым подмножеством API; ограничение фиксируется в перечне известных "
        "ограничений платформы.",
    ],
    "1.3.1": [
        "По сравнению с Unity 2D в Lynx открыт исходный код Rust-ядра и регрессионные "
        "сценарии волн 0–11; отсутствует аналог Asset Store, зато доступна построчная "
        "модификация platformer.rs и behavior_tree.rs в учебных целях.",
    ],
    "1.3.2": [
        "Godot использует дерево узлов; Lynx — плоский JSON v3 с diff в Git. Для диплома "
        "по программной инженерии это упрощает ревью изменений уровня и автоматизированную "
        "регрессию на демо-проектах.",
    ],
    "1.3.3": [],
    "1.3.4": [
        "MonoGame.Content.Pipeline загружает XNB-ассеты; в Lynx ассеты — обычные PNG "
        "в assets/textures и пути в JSON — проще для Git и учебных diff.",
    ],
    "1.4.1": [
        "Grid broadphase ~96 uu в platformer.rs индексирует сущности для парных "
        "коллизий только в соседних ячейках сетки — теоретическая сложность ближе "
        "к O(n) на разреженных уровнях платформера, а не O(n²).",
    ],
    "1.4.2": [
        "PatrolEnemy в platformer-demo — минимальный пример декларативного ИИ: один "
        "sequence и один leaf_patrol без вложенных selector — достаточно для защиты "
        "и волны 10 overlay.",
    ],
    "1.4.3": [
        "Измерение на среднем ПК: Intel i5, 16 ГБ RAM, Windows 11, Flutter 3.x, "
        "release-сборка client; platformer-demo — среднее scene_update 1,8–2,4 мс, "
        "paint 3,5–5,2 мс — запас относительно нормативов 4 и 8 мс.",
    ],
    "2.1.1": [
        "В границы дипломного продукта входят каталоги engine (Rust), client (Flutter), "
        "lynx-core (math, batch2d, задел LynxScript), projects/platformer-demo и "
        "projects/platformer-wave2, сценарии регрессии run-wave0 … run-wave11.",
        "Перспективное ядро lynx-core milestone M2 (пакетная отрисовка batch2d) не заменяет "
        "Legacy engine в дипломе, но демонстрирует эволюцию без смены формата v3.",
    ],
    "2.1.2": [
        "Сценарий проверки преподавателем: запуск автоматизированного сценария регрессии "
        "волны 0 на чистой машине — ожидается успешный cargo test, flutter test и визуальное "
        "совпадение UV спрайта героя в Play и SceneEditor.",
        "Сценарий indie-автора: export preset all → публикация ZIP на itch.io, веб-демо "
        "и APK без изменения twelve-строчного скрипта player.lua на объекте Player.",
    ],
    "2.1.3": [
        "Стек дополнен пакетами: mlua для Lua на объектах, serde для JSON, gamepads и "
        "NexusGamepadFeeder для передачи осей в scene_set_gamepad, go_router для навигации "
        "Hub/Editor, audioplayers для воспроизведения событий из очереди ядра.",
    ],
    "2.2.1": [
        "Компоненты представления: EngineMainPage, SceneEditor, GamePlayerScreen, "
        "GameWorldPainter, tilemap_layer_painter. Компоненты симуляции: Scene::update, "
        "platformer.rs, animation.rs, behavior_tree.rs, модуль Lua. Связь — engine_bridge (FFI).",
    ],
    "2.2.3": [
        "Подсистема симуляции агрегирует scene.rs (оркестрация update), platformer.rs "
        "(TILE_SOLID, TILE_ONE_WAY, grid broadphase ~96 uu), animation.rs (uv_rect после тика), "
        "behavior_tree.rs и bindings Lua. Подсистема моста — scene_to_engine_json и GamePlayLoader.",
        "Сортировка спрайтов в Play: sorting_layer из SceneLayer.sortOrder, затем order_in_layer "
        "из поля z объекта, затем id — по аналогии с Unity для предсказуемого порядка отрисовки.",
    ],
    "2.2.4": [
        "Алгоритм коллизии с тайлом в пять шагов: интеграция позиции по velocity; выбор "
        "ячеек AABB в сетке тайлмапа; разрешение по типу 0–4; grid broadphase для пар "
        "сущностей; обновление флага on_ground для PlatformerMotor и AnimStateMachine.",
        "При смене сцены обязательны scene_destroy и обнуление указателя на стороне Dart — "
        "требование чеклиста готовности продукта для предотвращения утечек FFI.",
    ],
    "2.3.1": [
        "Свойство rustBehaviorTree в properties объекта Dart маппится в поле behavior_tree "
        "рантайма Rust при экспорте scene_to_engine_json. PlatformerMotor и AnimStateMachine "
        "также живут в properties и десериализуются в Entity.",
        "Иерархия parentId: дочерние объекты получают мировые координаты после обновления "
        "родителя на этапе hierarchy в Scene::update.",
    ],
    "2.3.2": [
        "TilemapLayerData содержит чанки с полями cx, cy, tw, th, tile_ids, collision; "
        "редакторская панель «Тайлы» задаёт кисть по типу коллизии и autotile по четырём "
        "соседям в tile_ids.",
        "События анимации волны 9: в клипе events с frame и type signal name footstep — "
        "при смене кадра Rust помещает сигнал в очередь сцены; клиент воспроизводит звук. "
        "Редактор: AnimationPlayer v2, долгий тап на кадре для добавления события.",
        "Camera2D поддерживает dead_zone_half_w и dead_zone_half_h; комнаты rooms задают "
        "camera_min и camera_max для клампа после follow.",
    ],
    "2.3.3": [
        "Локальная структура проекта: project.json, scenes/main.json, assets/textures, "
        "скрипты player.lua. Облачные таблицы (задел): projects, scenes, scene_versions, "
        "billing_accounts; поле content_json хранит тело сцены v3.",
    ],
    "2.4.1": [
        "SceneEditor отображает дерево объектов, инспектор свойств PlatformerMotor и BT, "
        "панель тайлов с tilesetId из project.json. LynxPluginHost подключает extensions "
        "сцены без форка ядра.",
        "При ширине окна менее 840 px EngineMainPage переключается на нижнюю навигацию "
        "«Проект · Сцена · Панель»; выбор объекта на узком экране открывает вкладку «Панель».",
    ],
    "2.4.2": [
        "GamePlayerScreen использует BoxFit.contain и фон #0d1117; designWidth 960 и "
        "designHeight 540 берутся из project.json. Overlay BT: active — зелёный, breakpoint — красный.",
        "При короткой стороне менее 640 px отображаются сенсорные кнопки с теми же "
        "кодами клавиш, что WASD и пробел в Lua-скрипте героя.",
    ],
    "2.4.3": [
        "Микшер проекта: audioMasterVolume и audioBusVolumes из project.json передаются "
        "в audio_mixer при сборке сцены; в ядре нет DSP, только множители шин и master.",
        "Чеклист готовности продукта включает сквозной путь: шаблон проекта → правка → "
        "сохранение → Play → экспорт; пауза через scene_set_paused без утечки указателя сцены.",
    ],
    "2.5.1": [
        "Реализация PatrolAi: горизонтальный патруль между min_x и max_x, если у сущности "
        "нет behavior_tree. Враг PatrolEnemy в platformer-demo использует BT leaf_patrol.",
        "Lua на объекте Player: speed 260, jump 520, set_velocity(nvx, nvy); глобалы "
        "on_ground, key_a, key_d, key_space поставляет ядро после физики тайлов.",
        "PhysicsBody.one_way поддерживает односторонние платформы между сущностями, "
        "дополняя тайловые TILE_ONE_WAY.",
    ],
    "2.5.2": [
        "GamePlayLoader выполняет merge autoloadSceneIds, вызывает scene_to_engine_json, "
        "затем scene_create. Ticker GamePlayerScreen вызывает scene_update с ограниченным dt.",
        "Клиент в Play сначала использует uv_rect из JSON ядра; локальный пересчёт по "
        "elapsedSeconds — только fallback на Web без Rust. Это устраняет рассинхрон волны 0.",
        "Геймпад: NexusGamepadFeeder → scene_set_gamepad; в Lua доступны gp_lx, gp_a и "
        "play_sound_bus(path, bus, volume) согласован с очередью шин ядра.",
    ],
    "2.5.3": [
        "Пресет windows: Player.exe, каталог game_data, native engine.dll. Пресет web: "
        "сборка main_player.dart со static assets. Пресет android: APK с упакованным game_data.",
        "Параллельная реализация из темы диплома: одна команда preset all выдаёт три "
        "канала дистрибуции из одного project.json и наборов scenes/*.json.",
    ],
    "3.1.1": [
        "Альфа-тестирование Lynx проверяет соответствие FR-01…FR-08 и NFR-01…NFR-04 "
        "из таблицы 1 главы 1. Критичный качественный критерий — сценарий Play=Editor "
        "на platformer-demo в течение 60 секунд без расхождения UV и тайлмапа.",
    ],
    "3.2.1": [
        "Регрессионные сценарии по волнам: 0 — platformer-demo и UV; 1 — плагины; 2 — "
        "scene manager и platformer-wave2; 4 — скрипты; 9 — animation events footstep; "
        "10 — behavior tree overlay; 11 — platform parity Win/Web/Android.",
        "Эталонный прогон: cargo test в engine и lynx-core — пройдены; "
        "wave0_platformer_demo_test.dart — пройден; сценарий регрессии волны 0 — OK при "
        "установленном toolchain Flutter и Rust.",
        "Таблица бюджета при 1080p: scene_update ≤4 мс, Flutter paint ≤8 мс, аудио/IO ≤2 мс, "
        "запас ≥2 мс в рамках 16,7 мс кадра.",
    ],
    "3.3.1": [
        "Ручной сценарий BT врага: в Play включить overlay, убедиться что PatrolEnemy "
        "показывает путь leaf_patrol в overlay BT active. Сценарий wave2: Enter на menu "
        "переходит на сцену level без утечки указателя FFI.",
    ],
    "2.6.1": [
        "В platformer-demo объект Player несёт PlatformerMotor, AnimStateMachine и скрипт "
        "player.lua; враг PatrolEnemy — JSON behavior_tree с leaf_patrol между границами "
        "уровня. Эти объекты — эталон для регрессии волн 0 и 10.",
        "Автоматизированный сценарий волны 0 запускает cargo test в каталоге engine, "
        "flutter test с wave0_platformer_demo_test и проверяет отсутствие расхождения "
        "sprite.uv_rect между редактором и Player после 120 тиков по 1/60 с.",
    ],
    "2.6.2": [
        "Сценарий параллельной работы в Git: студент A правит scenes/level1.json, студент B — "
        "scenes/level2.json; общий autoload HUD подключается в project.json без конфликта "
        "в одном файле сцены.",
        "Поле collaboration в JSON v3 не блокирует офлайн-режим: при отсутствии сервера "
        "редактор работает локально, метаданные присутствия просто не синхронизируются.",
    ],
    "2.6.3": [
        "Модуль batch2d в lynx-core группирует квады спрайтов с общей текстурой для "
        "минимизации переключений состояния Canvas. Тесты lynx-core/src/math.rs и "
        "batch2d покрывают Aabb и упаковку вершин.",
        "LynxScript (M5 дорожной карты) планируется как замена Lua в hot path с тем же "
        "контрактом set_velocity и глобалов on_ground; в дипломе Lua остаётся рабочим "
        "решением волны 4.",
    ],
    "3.4.1": [
        "Таблица соответствия классическому платформеру SMB: тайлмап и коллизии 0–4 — да; "
        "PlatformerMotor и coyote — да; BT враги — да без визуального BT-редактора; "
        "полный паритет SMB по полировке — не заявлен.",
        "Ограничения альфа-версии: Web без полной Lua; нет визуального редактора BT; "
        "iOS/Android CI не на каждом PR. Направления: LynxScript M5, WASM batch2d, CI mobile.",
    ],
}
