#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate full diploma markdown (~70+ Word pages), coursework structure."""
from __future__ import annotations

import re
import sys
from pathlib import Path

_SCRIPTS = Path(__file__).resolve().parent
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

ROOT = Path(__file__).resolve().parent.parent.parent
OUT = ROOT / "Lynx" / "docs" / "DIPLOMA_LYNX_2D_FULL.md"
SRC = ROOT / "Lynx" / "docs" / "DIPLOMA_LYNX_2D_ENGINE.md"
EXPAND = ROOT / "Lynx" / "docs" / "DIPLOMA_LYNX_2D_ENGINE_EXPAND.md"

from diploma_chapters_unique import gen_chapter1, gen_chapter2, gen_chapter3
from diploma_supplement import gen_supplement
from diploma_volume_boost import append_boost

TITLE = (
    "Разработка кроссплатформенного игрового движка "
    "с поддержкой параллельной реализации двумерных игр"
)


def para(*sentences: str) -> str:
    return "\n\n".join(sentences) + "\n\n"


def bullets(items: list[str]) -> str:
    return "\n".join(f"– {x};" for x in items) + "\n\n"


def sanitize_diploma_text(text: str) -> str:
    """Replace file/path references with academic prose; keep meaning and volume."""
    subs: list[tuple[str, str]] = [
        (
            r"`?PERFORMANCE_BUDGET\.md`?",
            "нормативами производительности движка (шаг симуляции — не более 4 мс, "
            "отрисовка кадра — не более 8 мс при частоте 60 кадров в секунду)",
        ),
        (r"PERFORMANCE_BUDGET и метрики", "нормативы производительности и измеряемые метрики"),
        (
            r"`?GAME_AUTHOR\.md`?\s*§\s*\d+",
            "руководством для авторов игрового контента",
        ),
        (r"`?GAME_AUTHOR\.md`?", "руководством для авторов игрового контента"),
        (
            r"`?KNOWN_LIMITATIONS\.md`?",
            "официальным перечнем известных ограничений платформы",
        ),
        (
            r"KNOWN_LIMITATIONS и честные ограничения",
            "известные ограничения платформы и их документирование",
        ),
        (r"`?ROADMAP_WAVES\.md`?", "дорожной картой поэтапного развития функциональности"),
        (r"`?PLATFORM_QA\.md`?", "программой кроссплатформенной проверки качества"),
        (r"`?EXPORT\.md`?", "методикой экспорта готовых игровых сборок"),
        (
            r"`?EDITOR_GODOT_PARITY\.md`?",
            "чеклистом соответствия редактора общепринятым 2D-инструментам",
        ),
        (r"EDITOR_GODOT_PARITY для 2D", "соответствие редактора общепринятым 2D-инструментам"),
        (
            r"`?LYNX_CORE_ARCHITECTURE\.md`?",
            "архитектурным описанием перспективного ядра Lynx Core",
        ),
        (r"`?LYNX_CORE_M2\.md`?", "спецификацией этапа пакетной отрисовки спрайтов"),
        (r"`?DEPLOY\.md`?", "регламентом развёртывания"),
        (r"`?README\.md`?", "общим описанием проекта"),
        (r"D:\\\\PO\\\\Lynx(?:\\\\docs)?", "репозиторием исходного кода движка Lynx"),
        (r"D:\\PO\\Lynx(?:\\docs)?", "репозиторием исходного кода движка Lynx"),
        (
            r"run-wave0-regression\.ps1 … run-wave11-regression\.ps1",
            "автоматизированными сценариями регрессии волн с нулевой по одиннадцатую",
        ),
        (r"`run-wave(\d+)-regression\.ps1`", r"автоматизированным сценарием регрессии волны \1"),
        (r"run-wave(\d+)-regression\.ps1", r"автоматизированным сценарием регрессии волны \1"),
        (
            r"`run-all-regression\.ps1`(?:\s*-Tier\s+quick)?",
            "сводным сценарием быстрой регрессии",
        ),
        (r"run-all-regression\.ps1(?:\s*-Tier\s+quick)?", "сводным сценарием быстрой регрессии"),
        (r"`export-player\.ps1`", "утилитой пакетного экспорта Player"),
        (r"export-player\.ps1", "утилитой пакетного экспорта Player"),
        (
            r"Таблица SMB parity \(GAME_AUTHOR\.md §7\)",
            "Таблица соответствия возможностям классического платформера",
        ),
        (
            r"Lynx Project\. GAME_AUTHOR\.md, ROADMAP_WAVES\.md\. D:\\\\PO\\\\Lynx\\\\docs\\\\",
            "Техническая документация проекта Lynx. Репозиторий исходного кода (2026).",
        ),
        (
            r"GAME_AUTHOR\.md, ROADMAP_WAVES\.md, PLATFORM_QA\.md \[Электронный ресурс\]\. Репозиторий Lynx",
            "Техническая документация проекта Lynx [Электронный ресурс]",
        ),
        (r"# РАСШИРЕНИЯ ИЗ DIPLOMA_LYNX_2D_ENGINE_EXPAND", "# ДОПОЛНИТЕЛЬНЫЕ ПРАКТИЧЕСКИЕ МАТЕРИАЛЫ"),
        (r"файла `DIPLOMA_LYNX_2D_ENGINE\.md`", "основного текста дипломной работы"),
        (r"`projects/platformer-demo`", "демонстрационного проекта platformer-demo"),
        (r"projects/platformer-demo", "демонстрационного проекта platformer-demo"),
        (r"`projects/platformer-wave2`", "демонстрационного проекта platformer-wave2"),
        (r"projects/platformer-wave2", "демонстрационного проекта platformer-wave2"),
        (r"чеклист MVP п\.(\d+)", r"чеклисту готовности продукта (пункт \1)"),
        (r"\(таблица 2 — по `GAME_AUTHOR\.md`\)", "(таблица 2 — по разделению ответственности слоёв)"),
    ]
    for pattern, repl in subs:
        text = re.sub(pattern, repl, text)
    text = re.sub(
        r"\b([A-Z][A-Z0-9_]{2,})\.md\b",
        "соответствующем разделе технической документации",
        text,
    )
    return text


def dedupe_paragraphs(text: str) -> str:
    """Remove verbatim duplicate paragraphs; keep headings, tables, code."""
    blocks = text.split("\n\n")
    seen: set[str] = set()
    out: list[str] = []
    for b in blocks:
        s = b.strip()
        if not s:
            continue
        if s.startswith("#") or s.startswith("|") or s.startswith("```") or s.startswith("**ДИПЛОМ"):
            out.append(s)
            continue
        if s.startswith("– ") or s.startswith("- "):
            out.append(s)
            continue
        key = re.sub(r"\s+", " ", s)[:250]
        if key in seen:
            continue
        seen.add(key)
        out.append(s)
    return "\n\n".join(out) + "\n"


def load_body(path: Path, skip_meta: bool = True) -> str:
    if not path.exists():
        return ""
    lines = path.read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    skip_until_intro = skip_meta
    for line in lines:
        if skip_until_intro:
            if line.startswith("## ВВЕДЕНИЕ") or line.startswith("## 1 "):
                skip_until_intro = False
            else:
                continue
        if line.startswith("# Дипломная") or line.startswith("> "):
            continue
        if line.startswith("## ЗАКЛЮЧЕНИЕ") or line.startswith("# ЗАКЛЮЧЕНИЕ"):
            break
        if line.strip() == "---":
            continue
        out.append(line)
    return "\n".join(out)


def load_expand(path: Path) -> str:
    if not path.exists():
        return ""
    lines = path.read_text(encoding="utf-8").splitlines()
    out: list[str] = []
    started = False
    for line in lines:
        if line.startswith("> ") or line.startswith("# Диплом Lynx"):
            continue
        if line.startswith("## Расширение"):
            started = True
        if started:
            out.append(line)
    return "\n".join(out)


def gen_title_page() -> str:
    return f"""МИНПРОСВЕЩЕНИЯ РОССИИ
Федеральное государственное бюджетное образовательное учреждение высшего образования
«Тульский государственный педагогический университет им. Л.Н. Толстого»
(ТГПУ им. Л.Н. Толстого)

**ДИПЛОМНАЯ РАБОТА**

По направлению подготовки:
09.03.04 «Программная инженерия»

**Тема:**
«{TITLE}»

Студент: _________________________
Группа: _________________________

Научный руководитель: _________________________
доктор технических наук, профессор

Тула 2026

---

## СОДЕРЖАНИЕ

Введение
1 Теоретическая часть
1.1 Описание и анализ предметной области
1.1.1 Понятие двумерной игры и игрового движка
1.1.2 Жизненный цикл кадра и подсистемы движка
1.1.3 Кроссплатформенность и параллельная реализация игр
1.1.4 Требования к движку и постановка задачи
1.2 Теоретические основы игровых движков
1.2.1 Архитектурные паттерны и разделение слоёв
1.2.2 Физика, анимация и поведение в 2D
1.2.3 Форматы данных, сцены и экспорт
1.3 Существующие аналоги
1.3.1 Unity 2D
1.3.2 Godot Engine
1.3.3 Construct 3
1.3.4 MonoGame и libGDX
1.3.5 Сравнительный анализ
1.4 Теоретическая привязка механик Lynx к платформеру
1.4.1 Типы тайловых ячеек и коллизий
1.4.2 Узлы поведенческого дерева
1.4.3 Нормативы производительности 2D-кадра
2 Практическая часть
2.1 Проектирование итогового продукта
2.1.1 Концепция продукта Lynx и границы системы
2.1.2 Функциональные требования и сценарии использования
2.1.3 Выбор средств программной реализации
2.2 Проектирование архитектуры
2.2.1 Диаграмма компонентов системы
2.2.2 ER-диаграмма данных проекта и сцены
2.2.3 Модульность: крупные подсистемы
2.2.4 Диаграмма потоков данных и последовательности Play
2.3 Проектирование данных и хранения
2.3.1 Модель объектов сцены
2.3.2 Тайлмапы, комнаты и анимация
2.3.3 Организация хранения проекта
2.4 Проектирование UI/UX
2.4.1 Интерфейс редактора
2.4.2 Интерфейс режима Play
2.4.3 Адаптивность и сценарии взаимодействия
2.5 Реализация ключевых компонентов
2.5.1 Подсистема симуляции
2.5.2 Подсистема клиента и FFI-мост
2.5.3 Экспорт и параллельные пресеты
2.5.4 Детальное описание platformer-demo
2.5.5 Детальное описание platformer-wave2
2.6 Поэтапное развитие, плагины и перспективное ядро
2.6.1 Дорожная карта волн 0–11
2.6.2 Совместная работа и облачный задел
2.6.3 Lynx Core M2: пакетная отрисовка
2.7 Пошаговая реализация клиентских и серверных модулей
3 Альфа-тестирование
3.1 Методика альфа-тестирования
3.2 Автоматизированное альфа-тестирование
3.3 Ручное альфа-тестирование
3.4 Оценка результатов альфа-тестирования
Заключение
Список использованной литературы
Приложения

---
"""


def gen_introduction() -> str:
    return (
        "## ВВЕДЕНИЕ\n\n"
        + para(
            "Современная индустрия разработки двумерных видеоигр (платформеры, аркады, "
            "головоломки, RPG с видом сверху) опирается на специализированные игровые движки — "
            "программные платформы, объединяющие симуляцию мира, обработку ввода, анимацию "
            "спрайтов, физику коллизий и инструменты создания уровней. Коммерческие решения "
            "(Unity 2D, Godot, Construct) обеспечивают широкую функциональность, однако связаны "
            "с лицензированием, закрытыми рантаймами и зависимостью от экосистемы вендора. "
            "Для учебных заведений, инди-студий и исследовательских проектов актуальна разработка "
            "собственного кроссплатформенного движка, позволяющего параллельно создавать и "
            "публиковать несколько 2D-игр под Windows, Web и мобильные платформы из единого "
            "формата проекта.",
            "Традиционные подходы «игра на чистом SDL/OpenGL» требуют от автора реализации "
            "инфраструктуры (окно, рендер, физика, редактор уровней), что отвлекает от "
            "предметной области — геймдизайна и логики уровня. Использование только визуальных "
            "конструкторов, напротив, не даёт доступа к ядру симуляции и ограничивает научную "
            "ценность дипломного исследования. Платформа Lynx занимает промежуточную позицию: "
            "открытое Rust-ядро симуляции, Flutter-редактор и Player, документированный JSON "
            "формата сцены v3 и автоматизированные сценарии регрессионной верификации качества.",
            "Под параллельной реализацией двумерных игр в рамках данной работы понимается: "
            "(1) кроссплатформенный экспорт — один проект собирается в артефакты Windows, Web "
            "и Android без переписывания игровой логики; (2) параллельная разработка контента — "
            "несколько сцен, autoload, менеджер сцен (load_scene, push_scene, pop_scene); "
            "(3) параллельная работа авторов — collab-presence и CRDT в редакторе; "
            "(4) разделение потоков ответственности — симуляция в Rust, отрисовка во Flutter.",
            "Актуальность темы обусловлена потребностью в отечественной и учебной технологической "
            "базе для подготовки программистов игровой индустрии, необходимостью прозрачного стека "
            "(без закрытого runtime) и задачей воспроизводимого качества через автоматизированную "
            "регрессию (автоматизированные сценарии проверки волн с нулевой по одиннадцатую).",
        )
        + para(
            "Объектом исследования является процесс проектирования, реализации и тестирования "
            "кроссплатформенных двумерных игр в программной среде Lynx.",
            "Предметом исследования является игровой движок Lynx: архитектура подсистем "
            "симуляции 2D, формат сцены v3, интеграция Rust–Flutter через FFI, экспорт Player "
            "и методика тестирования.",
            f"Целью дипломной работы является разработка и описание кроссплатформенного "
            f"игрового движка Lynx, обеспечивающего полный цикл создания 2D-игры "
            f"(редактирование → Play → экспорт) с поддержкой параллельной реализации "
            f"игровых проектов на целевых платформах.",
        )
        + "Для достижения поставленной цели необходимо решить следующие задачи:\n\n"
        + bullets(
            [
                "провести анализ предметной области 2D-игр и существующих аналогов",
                "спроектировать архитектуру движка с разделением Rust и Flutter",
                "разработать модели данных формата сцены v3",
                "реализовать ключевые компоненты: платформерную физику, анимацию, BT, менеджер сцен",
                "реализовать пользовательский интерфейс редактора и режима Play",
                "выполнить комплексное тестирование: unit-тесты, регрессия волн 0–11, ручные сценарии",
            ]
        )
        + para(
            "Практическая значимость работы заключается в создании готовой к использованию "
            "платформы для учебной и indie-разработки 2D-игр, эталонных проектов platformer-demo "
            "и platformer-wave2, а также полного комплекта технической и регрессионной документации.",
            "Методы исследования: анализ литературы, сравнительный анализ, системный анализ, "
            "объектно-ориентированное и модульное проектирование, прототипирование, модульное "
            "и интеграционное тестирование.",
            "Структура работы: введение; теоретическая часть (анализ предметной области и "
            "игровых движков); практическая часть (проектирование продукта, архитектуры, "
            "данных, UI/UX и реализация); альфа-тестирование; заключение; список литературы; "
            "приложения с листингами и диаграммами.",
            "Научная новизна в рамках бакалавриата: согласованная архитектура Rust–Flutter "
            "для 2D с критерием Play=Editor как формальной регрессией; поэтапная дорожная "
            "карта волн 0–11 с автоматизированной приёмкой каждого инкремента; единый JSON v3 "
            "для редактора, native FFI и упрощённого WebSceneEngine.",
        )
        + append_boost("intro")
    )


def gen_conclusion() -> str:
    s = "# ЗАКЛЮЧЕНИЕ\n\n"
    s += para(
        "В ходе выполнения дипломной работы разработан кроссплатформенный игровой движок Lynx "
        "с поддержкой параллельной реализации двумерных игр.",
    )
    results = [
        "В теоретической части систематизирована предметная область 2D-игр, принципы "
        "работы движков и требования; выполнен сравнительный анализ аналогов.",
        "В практической части спроектирован продукт Lynx: архитектура, ER-модель данных, "
        "модульность, UI/UX и реализация подсистем симуляции, клиента и экспорта.",
        "Выполнено альфа-тестирование: модульные тесты, регрессия волн 0–11, "
        "10 ручных сценариев, кроссплатформенная матрица.",
        "Подтверждена параллельная реализация: экспорт Win/Web/Android, multi-scene, autoload.",
        "Эталонные демо platformer-demo и platformer-wave2 воспроизводят заявленный функционал.",
        "Зафиксированы ограничения альфа-версии и направления развития (LynxScript, CI mobile).",
    ]
    for i, r in enumerate(results, 1):
        s += f"{i}. {r}\n\n"
    s += "Оценка достижения задач:\n\n"
    for i in range(1, 7):
        s += f"{i}. Задача {i} выполнена — подтверждено регрессией и демо-проектами.\n\n"
    s += para(
        "Практическая ценность — платформа для учебной и indie-разработки 2D без лицензии "
        "коммерческого движка. Направления развития: Lynx Core M5 LynxScript, CI mobile, "
        "визуальный BT-редактор.",
    )
    s += append_boost("conclusion")
    return s


def gen_references() -> str:
    refs = [
        "Gregory, J. Game Engine Architecture. 3rd ed. CRC Press, 2018.",
        "Schell, J. The Art of Game Design. 3rd ed. CRC Press, 2019.",
        "Nystrom, R. Game Programming Patterns. Genever Benning, 2014.",
        "Буч Г., Рамбо Д., Якобсон А. Язык UML. М.: ДМК Пресс, 2006.",
        "Sommerville, I. Software Engineering. 10th ed. Pearson, 2016.",
        "The Rust Programming Language. https://doc.rust-lang.org/book/",
        "Flutter Documentation. https://docs.flutter.dev/",
        "Godot Engine Documentation. https://docs.godotengine.org/",
        "Unity Manual 2D. https://docs.unity3d.com/Manual/Unity2D.html",
        "Техническая документация проекта Lynx. Репозиторий исходного кода (2026).",
        "Дудкин Я.Ю. Курсовая работа «Разработка приложения для мониторинга восстановления пациентов». ТГПУ, 2026.",
    ]
    s = "# СПИСОК ИСПОЛЬЗОВАННОЙ ЛИТЕРАТУРЫ\n\n"
    for i, r in enumerate(refs, 1):
        s += f"{i}. {r}\n"
    return s + "\n"


def gen_appendices() -> str:
    s = "# ПРИЛОЖЕНИЯ\n\n"
    apps = [
        (
            "А",
            "Структура репозитория Lynx",
            "Каталог engine: scene.rs, platformer.rs, animation.rs, behavior_tree.rs, "
            "lua.rs, lib.rs (FFI). Каталог client/lib: engine_bridge.dart, "
            "scene_to_engine_json.dart, game_play_loader.dart, game_world_painter.dart, "
            "scene_editor.dart, web_scene_engine.dart. Каталог projects: platformer-demo, "
            "platformer-wave2. Каталог lynx-core: math, batch2d.",
        ),
        (
            "Б",
            "project.json platformer-demo",
            "Поля: designWidth 960, designHeight 540, startupSceneId main, projectMode 2d, "
            "inputMap (move_left, jump), autoloadSceneIds (опционально), tilesets с "
            "texturePath, audioMasterVolume, audioBusVolumes.",
        ),
        (
            "В",
            "Фрагмент main.json",
            "formatVersion 3; objects[] с Player и PatrolEnemy; tilemapLayers[] с "
            "чанками tile_ids и collision; layers[] с sortOrder; rooms[] с camera_min/max; "
            "animationClips[] с events footstep.",
        ),
        (
            "Г",
            "Сценарии регрессионного тестирования",
            "Волны 0–11: каждая волна — cargo test, flutter test, при необходимости "
            "export и ручная проверка по таблице 11. Волна 0 — wave0_platformer_demo_test; "
            "волна 11 — triple export Win/Web/Android.",
        ),
        (
            "Д",
            "Таблица соответствия классическому платформеру",
            "См. таблицу SMB в конце работы: тайлмап, one-way, coyote, BT, AnimSM, "
            "camera dead zone, multi-room, audio buses, gamepad — реализовано в Lynx.",
        ),
        (
            "Е",
            "Листинг player.lua",
            "12 строк: speed 260, jump 520, key_a/key_d/key_space, set_velocity(nvx,nvy). "
            "Глобалы on_ground и vy поставляет ядро после физики тайлов.",
        ),
        (
            "Ж",
            "FFI scene_update",
            "Экспорт lib.rs: scene_create(json) → указатель; scene_update(ptr, dt); "
            "scene_destroy(ptr); scene_set_paused; scene_set_gamepad. Dart хранит ptr как int.",
        ),
        (
            "З",
            "Протокол альфа-теста",
            "Таблица 8 — десять ручных сценариев; протоколы BOOST раздела 3 — пошаговые "
            "инструкции с ожидаемым результатом pass/fail.",
        ),
    ]
    for letter, title, body in apps:
        s += f"## Приложение {letter}. {title}\n\n{body}\n\n"

    return s


def gen_smb_table() -> str:
    return (
        "## Таблица соответствия возможностям классического платформера\n\n"
        "| Требование SMB | Lynx | Комментарий |\n"
        "|----------------|------|-------------|\n"
        "| Большой тайлмап | Да | atlas в Play |\n"
        "| One-way, склоны | Да | TILE_* |\n"
        "| Motor + coyote | Да | PlatformerMotor |\n"
        "| BT враги | Да | JSON BT |\n"
        "| Anim SM | Да | AnimStateMachine |\n"
        "| Camera dead zone | Да | Camera2D |\n"
        "| Multi-room | Да | rooms |\n"
        "| Audio buses | Да | очереди |\n"
        "| Gamepad | Да | FFI |\n\n"
    )


def main() -> None:
    parts = [
        gen_title_page(),
        gen_introduction(),
        gen_chapter1(),
        gen_chapter2(),
        gen_chapter3(),
    ]
    core = "".join(parts)
    sup = gen_supplement(core, sanitize_diploma_text)
    parts.extend([
        sup,
        gen_conclusion(),
        gen_references(),
        gen_appendices(),
        gen_smb_table(),
    ])
    text = dedupe_paragraphs(sanitize_diploma_text("".join(parts)))
    OUT.write_text(text, encoding="utf-8")
    pages = len(text) // 1800
    print(f"Written {OUT}")
    print(f"  chars: {len(text)}")
    print(f"  est. pages: {pages}")


if __name__ == "__main__":
    main()
