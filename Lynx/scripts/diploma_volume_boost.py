# -*- coding: utf-8 -*-
"""Дополнительный объём — уникальные технические блоки Lynx."""

BOOST: dict[str, list[str]] = {
    "intro": [
        "Платформа Lynx в дипломной реализации включает пять каталогов верхнего уровня: "
        "engine — Rust-библиотека симуляции с FFI; client — Flutter-приложение Hub, "
        "редактора и Player; lynx-core — перспективное ядро batch2d; projects — "
        "демонстрационные игры platformer-demo и platformer-wave2; scripts — "
        "автоматизация экспорта и регрессии без упоминания имён файлов в тексте работы.",
        "Ключевой измеримый результат диплома — воспроизводимый критерий волны 0: "
        "при неизменном main.json отрисовка в SceneEditor и GamePlayerScreen совпадает "
        "по sprite.uv_rect объекта Player на каждом кадре 60 FPS в течение не менее "
        "60 секунд наблюдения; отклонение фиксируется как блокирующий дефект альфы.",
    ],
    "2.wave2": [
        "Демонстрационный проект platformer-wave2 иллюстрирует FR-06 (многосценность). "
        "project.json указывает startupSceneId menu; сцена menu содержит UI-текст "
        "и скрипт menu.lua; сцена level — упрощённый платформерный уровень.",
        "Скрипт menu.lua: при on_key_enter вызывается load_scene с id level; "
        "GamePlayLoader уничтожает предыдущий указатель scene_destroy и создаёт новый "
        "scene_create для level.json — критично для отсутствия утечек FFI.",
        "Autoload: при необходимости HUD-сцена в autoloadSceneIds подмешивается "
        "до сериализации в ядро — объекты HUD появляются в каждой сцене Play без "
        "дублирования в menu.json и level.json.",
        "Параллельная разработка: автор A правит menu.json (титульный экран), "
        "автор B — level.json (геймплей); merge в Git без конфликта при разных файлах.",
        "Регрессия волны 2: автотест scene manager + ручной сценарий 5 (Enter → level). "
        "Повторить переход 10 раз — ожидание: стабильная загрузка, FPS без просадки.",
        "Отличие от platformer-demo: wave2 не эталон UV волны 0, а эталон смены сцен; "
        "оба проекта обязательны на защите для полноты FR-01 и FR-06.",
    ],
    "2.demo": [
        "Демонстрационный проект platformer-demo — эталон диплома и волны 0. "
        "Разрешение проекта 960×540 задаётся в project.json и используется "
        "GamePlayerScreen для AspectRatio и расчёта letterbox.",
        "Объект Player: позиция старта на платформе из тайлмапа; PlatformerMotor с "
        "run_speed 260, jump_speed 520, gravity_scale 1.0; AnimStateMachine переключает "
        "idle/run/jump; scriptPath указывает на player.lua с set_velocity.",
        "Объект PatrolEnemy: без Lua; properties.rustBehaviorTree — sequence с "
        "leaf_patrol min_x 120 max_x 480; спрайт врага на слое Entities; в Play "
        "overlay BT подсвечивает leaf_patrol зелёным при активном патруле.",
        "Camera2D: follow на Player; dead_zone_half_w и dead_zone_half_h создают "
        "«мёртвую зону» в центре экрана; rooms ограничивают camera_min и camera_max "
        "при выходе героя в новую зону уровня.",
        "Тайлмап уровня: чанки 16×16; типы collision 1 на полу, 2 на one-way "
        "платформах, 0 в воздухе; визуальные tile_ids из autotile набора tileset "
        "platformer_tiles.png.",
        "Слои отрисовки: Background (тайлмап), Entities (Player, PatrolEnemy), "
        "Foreground (декор); sortOrder Background < Entities < Foreground гарантирует "
        "правильный painter's order.",
        "Звук: клип run содержит событие footstep на кадре 3; при беге героя "
        "ядро эмитит сигнал; клиент воспроизводит assets/audio/footstep.wav на шине "
        "SFX с громкостью из audioBusVolumes.",
        "Ввод: inputMap move_left → KeyA, jump → Space; на тач-экране <640 px "
        "те же действия через экранные кнопки; геймпад — ось gp_lx и кнопка gp_a "
        "в Lua эквивалентны A и Space.",
    ],
    "2.1": [
        "Диаграмма вариантов использования (рисунок 4, вставить в Word): актор «Автор» — "
        "редактировать сцену, Play, экспорт; актор «Игрок» — запуск Player.exe или Web; "
        "актор «Преподаватель» — регрессия волны 0; актор «Студент 2» — параллельная "
        "правка level2.json в Git.",
        "Ограничение scope диплома: не реализуется сетевой мультиплеер; не реализуется "
        "полный визуальный редактор BT; не заявляется коммерческая SLA облака — только "
        "локальный редактор и задел ER для scene_versions.",
    ],
    "2.3": [
        "Фрагмент main.json (концептуально): корневые массивы objects, tilemapLayers, "
        "layers, rooms, animationClips; formatVersion 3; объект Player с transform "
        "{x,y}, sprite, properties.platformerMotor, scriptPath scripts/player.lua.",
        "Чанк тайлмапа: поля cx, cy задают индекс чанка в сетке; tw, th — размер "
        "чанка в ячейках (типично 16×16); tile_ids — плоский массив индексов в атлас; "
        "collision — параллельный массив типов 0–4 той же длины.",
        "AnimationClip run_clip: frames — список {duration, uv_x, uv_y, uv_w, uv_h}; "
        "events — [{frame:3, type:signal, name:footstep}]; clip привязан к "
        "animStateMachine состояния run.",
    ],
    "2.5": [
        "Листинг 3 — фрагмент behavior_tree врага PatrolEnemy (properties.rustBehaviorTree): "
        "корневой узел type sequence с дочерним leaf_patrol; поля min_x и max_x задают "
        "горизонтальный интервал патруля в мировых координатах уровня platformer-demo.",
        "Листинг 4 — фрагмент AnimStateMachine героя: состояние idle с клипом idle_clip, "
        "переход в run при |vx|>10, переход в jump при on_ground=false; параметры "
        "хранятся в properties.animStateMachine и сериализуются в ядро без потери.",
        "Структура каталога демонстрационного проекта platformer-demo: project.json в корне; "
        "подкаталог scenes с main.json; assets/textures с атласом тайлсета; scripts/player.lua "
        "на объекте Player через поле scriptPath в main.json.",
    ],
    "3": [
        "Матрица трассируемости FR → тест: FR-01 → открытие demo + сохранение; FR-02 → "
        "нормативы 4/8 мс; FR-03 → сценарий coyote + тайлы 0–4; FR-04 → gamepad сценарий 9; "
        "FR-05 → footstep сценарий 10; FR-06 → wave2 Enter; FR-07 → export Win/Web; "
        "FR-08 → таблица 11 волн.",
        "Протокол ручного сценария 1 (открытие demo): запустить клиент Lynx; в Hub выбрать "
        "platformer-demo; дождаться загрузки SceneEditor; в дереве объектов видны Player, "
        "PatrolEnemy, Camera2D; на холсте отображается тайлмап и спрайты — ожидание: без "
        "ошибок в консоли, formatVersion 3 в инспекторе сцены.",
        "Протокол сценария 2 (Play=Editor): не изменяя сцену, нажать Play; 60 секунд "
        "наблюдать героя; сделать скриншот редактора и Play; сравнить UV прямоугольник "
        "спрайта Player — ожидание: совпадение; при расхождении — блокер альфы, завести "
        "дефект с логом scene_update.",
        "Протокол сценария 3 (coyote jump): в Play подвести Player к краю one-way платформы; "
        "сойти в воздух; в течение coyote frames нажать пробел — ожидание: прыжок выполнен; "
        "повторить с отключённым coyote в properties — прыжок не выполняется в воздухе.",
        "Протокол сценария 6 (Export Win): выполнить экспорт preset windows для "
        "platformer-demo; распаковать ZIP на машине без Flutter; запустить Player.exe — "
        "ожидание: загрузка уровня, управление WASD, звук footstep при беге.",
        "Протокол сценария 10 (Footstep): в редакторе открыть AnimationPlayer клипа run; "
        "убедиться в событии frame 3 type signal name footstep; Play — ожидание: щелчок "
        "шага синхронен с кадром анимации бега.",
        "Протокол сценария 4 (BT враг): Play platformer-demo; меню → BT overlay on; "
        "наблюдать PatrolEnemy — в списке узлов активен leaf_patrol; путь debug_path "
        "содержит строку leaf_patrol — pass.",
        "Протокол сценария 5 (Смена сцены): открыть platformer-wave2; Play; на menu "
        "нажать Enter; загрузился level, герой или подсказка видны; Esc/назад если "
        "реализовано — без crash; 10 циклов — pass.",
        "Протокол сценария 8 (Touch): сузить окно браузера или эмулятор до ширины "
        "580 px; Play platformer-demo; появились сенсорные кнопки; тап влево/вправо/прыжок "
        "двигают Player — pass.",
        "Протокол сценария 9 (Gamepad): подключить геймпад; Play; движение по оси "
        "gp_lx и прыжок gp_a в player.lua — pass; отключить геймпад — клавиатура работает.",
        "Классификация дефектов альфы: Blocker — UV волны 0, crash FFI, export не "
        "запускается; Major — Web без Play, footstep не слышен; Minor — UI <840 px, "
        "опечатки Hub; Trivial — цвет overlay.",
    ],
    "1": [
        "Теоретическая декомпозиция ввода в 2D: устройство → скан-код → action map → "
        "глобалы скрипта. В Lynx action map задаётся inputMap в project.json; ядро "
        "транслирует KeyA в key_a до вызова Lua, что отделяет раскладку клавиатуры от "
        "логики player.lua.",
        "Теория сортировки 2D: painter's algorithm по (sorting_layer, order_in_layer, id). "
        "В Lynx sorting_layer наследуется из SceneLayer.sortOrder; order_in_layer — из z "
        "объекта. Прозрачность спрайтов в дипломной сборке не используется — только "
        "непрозрачные квады Canvas.",
        "Теория dual-runtime: на native симуляция authoritative в Rust; на Web — "
        "WebSceneEngine с подмножеством API. Диплом трактует это как осознанный компромисс "
        "NFR-04, а не как технический долг без документации.",
    ],
    "2.4": [
        "Макет EngineMainPage при ширине ≥840 px: левая колонка 240 px — дерево проекта "
        "и список сцен; центр — холст SceneEditor с сеткой; правая колонка 280 px — "
        "инспектор выбранного объекта и панель слоёв.",
        "Макет при <840 px: нижняя панель с тремя вкладками; холст занимает всю ширину; "
        "инспектор скрыт до выбора объекта — тогда активная вкладка переключается на "
        "«Панель» автоматически, чтобы не терять контекст на телефоне в landscape.",
        "Цветовая схема Play: фон letterbox #0d1117; overlay BT — зелёный #3fb950 для "
        "active, красный #f85149 для breakpoint; сенсорные кнопки — полупрозрачные круги "
        "в углах экрана с иконками стрелок и прыжка.",
    ],
    "2.6": [
        "Детализация волны 4: привязка mlua к Entity по scriptPath; sandbox без файловой "
        "системы; ошибка Lua логируется в stderr engine без падения всей сцены — "
        "автор видит пустое поведение героя и исправляет player.lua.",
        "Детализация волны 9: AnimationPlayer v2 в редакторе; долгий тап на timeline "
        "кадра открывает диалог добавления события; тип signal с именем произвольный, "
        "footstep — соглашение demo-проекта.",
        "Детализация волны 10: меню Play → «BT overlay»; debug_path из Rust обновляется "
        "каждый тик; breakpoint задаётся строкой в настройках Play session.",
        "Детализация волны 11: один project.json прогоняется через export preset all; "
        "проверка Win — запуск exe; Web — статика в Chrome; Android — установка APK "
        "на эмулятор; критерий — загрузка одной и той же main.json без ручной правки.",
    ],
    "2.impl": [
        "Реализация Hub: список проектов из каталога projects; кнопка «Открыть» загружает "
        "project.json и переходит на EngineMainPage с выбранной startupSceneId.",
        "Реализация SceneEditor: StatefulWidget с выбранным objectId; холст преобразует "
        "координаты мыши в мировые с учётом zoom и pan; перемещение объекта пишет "
        "transform в Dart Scene и сохраняет на диск по Ctrl+S.",
        "Реализация tilemap_layer_painter: для каждого чанка рисуется сетка tile_ids "
        "через drawImageRect из атласа tileset; режим коллизии показывает цветовой "
        "оверлей 0–4 поверх ячеек для автора.",
        "Реализация GamePlayLoader.load: читает project.json; загружает startup scene; "
        "для каждого autoloadSceneId merge объектов и слоёв; вызывает scene_to_engine_json; "
        "передаёт JSON в scene_create; сохраняет pointer.",
        "Реализация Ticker в GamePlayerScreen: SchedulerBinding.scheduleFrameCallback; "
        "dt = min(elapsed, 1/30); scene_update(pointer, dt); setState с новыми позициями.",
        "Реализация GameWorldPainter.paint: для каждого объекта drawRect UV из sprite.uv_rect; "
        "для tilemapLayers — делегат tilemap_layer_painter; сортировка списка перед циклом.",
        "Реализация scene_set_paused: в scene.rs флаг paused пропускает интеграцию velocity "
        "и Lua, но камера может обновляться для плавности — в дипломной сборке пауза "
        "полная.",
        "Реализация audio_mixer на клиенте: после update опрос очереди сцены; для каждого "
        "события play(path, volume * busVolume * master); audioplayers AudioPlayer play.",
        "Реализация export preset web: flutter build web; копирование build/web и game_data "
        "в dist/web; index.html ссылается на main_player.dart.js.",
        "Реализация export preset android: flutter build apk; упаковка game_data в assets "
        "flutter; libengine.so в jniLibs для FFI на устройстве.",
        "Реализация LynxPluginHost: читает extensions[].type; для type editor_panel "
        "регистрирует виджет в боковой панели; ошибка плагина не ломает SceneEditor.",
        "Реализация WebSceneEngine: класс Dart с методами update, getPositions, getUvRects "
        "без dart:ffi; упрощённая гравитация и без mlua; документировано в ограничениях NFR-04.",
    ],
    "conclusion": [
        "По итогам диплома Lynx демонстрирует полный учебный цикл: теория 2D-кадра и "
        "аналогов → проектирование ER и компонентов → реализация Scene::update и "
        "GameWorldPainter → альфа с таблицами 7–11. Эталон platformer-demo воспроизводим "
        "на защите без доступа к исходным скриптам регрессии — достаточно инструкции "
        "запуска клиента и демо-проекта.",
        "Перспектива развития: интеграция batch2d в GameWorldPainter; LynxScript вместо "
        "Lua в hot path; визуальный редактор BT; CI mobile на каждый pull request; "
        "полноценный collab-сервер с scene_versions и разрешением 409.",
    ],
}


def append_boost(chapter_key: str) -> str:
    """Вернуть объединённые абзацы для ключа главы."""
    parts = BOOST.get(chapter_key, [])
    return "".join(p + "\n\n" for p in parts)
