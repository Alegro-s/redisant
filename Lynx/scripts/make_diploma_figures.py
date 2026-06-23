# -*- coding: utf-8 -*-
"""Чёткие диаграммы для диплома Lynx — без наложений и «каши» стрелок."""
from __future__ import annotations

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch
from pathlib import Path

ROOT_OUT = Path(r"D:\PO")
FIGURES_OUT = Path(r"D:\PO\Lynx\docs\figures")

# Палитра иерархии
C_PRESENT = "#D6EAF8"
C_BRIDGE = "#FDEBD0"
C_SIM = "#D5F5E3"
C_INFRA = "#E8DAEF"
C_UI = "#FADBD8"
C_BORDER = "#2C3E50"
C_ARROW = "#34495E"
C_TEXT = "#1A1A1A"
C_MUTED = "#5D6D7E"

plt.rcParams.update(
    {
        "font.family": "DejaVu Sans",
        "font.size": 10,
        "figure.facecolor": "white",
        "axes.facecolor": "white",
    }
)


def _new_fig(w: float, h: float):
    fig, ax = plt.subplots(figsize=(w, h), dpi=150)
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.set_aspect("equal")
    ax.axis("off")
    return fig, ax


def _save(fig, name: str):
    for folder in (FIGURES_OUT, ROOT_OUT):
        folder.mkdir(parents=True, exist_ok=True)
        fig.savefig(
            folder / name,
            dpi=300,
            bbox_inches="tight",
            pad_inches=0.35,
            facecolor="white",
        )
    plt.close(fig)


def _rounded_box(
    ax,
    x: float,
    y: float,
    w: float,
    h: float,
    title: str,
    body: list[str] | None = None,
    *,
    facecolor: str = "white",
    title_size: int = 11,
    body_size: int = 9,
):
    patch = FancyBboxPatch(
        (x, y),
        w,
        h,
        boxstyle="round,pad=0.02,rounding_size=1.2",
        linewidth=1.6,
        edgecolor=C_BORDER,
        facecolor=facecolor,
        zorder=2,
    )
    ax.add_patch(patch)
    ax.text(
        x + w / 2,
        y + h - 2.2,
        title,
        ha="center",
        va="top",
        fontsize=title_size,
        fontweight="bold",
        color=C_TEXT,
        zorder=3,
    )
    if body:
        ax.text(
            x + w / 2,
            y + h - 6.5,
            "\n".join(body),
            ha="center",
            va="top",
            fontsize=body_size,
            color=C_TEXT,
            linespacing=1.35,
            zorder=3,
        )


def _v_arrow(ax, x: float, y1: float, y2: float, label: str = "", label_side: str = "right"):
    ax.add_patch(
        FancyArrowPatch(
            (x, y1),
            (x, y2),
            arrowstyle="-|>",
            mutation_scale=14,
            linewidth=1.5,
            color=C_ARROW,
            shrinkA=2,
            shrinkB=2,
            zorder=1,
        )
    )
    if label:
        dx = 2.5 if label_side == "right" else -2.5
        ha = "left" if label_side == "right" else "right"
        ax.text(
            x + dx,
            (y1 + y2) / 2,
            label,
            ha=ha,
            va="center",
            fontsize=8.5,
            color=C_MUTED,
            style="italic",
            zorder=4,
        )


def _h_arrow(ax, x1: float, x2: float, y: float, label: str = "", above: bool = True):
    ax.add_patch(
        FancyArrowPatch(
            (x1, y),
            (x2, y),
            arrowstyle="-|>",
            mutation_scale=14,
            linewidth=1.5,
            color=C_ARROW,
            shrinkA=2,
            shrinkB=2,
            zorder=1,
        )
    )
    if label:
        va = "bottom" if above else "top"
        offset = 1.8 if above else -1.8
        ax.text(
            (x1 + x2) / 2,
            y + offset,
            label,
            ha="center",
            va=va,
            fontsize=8.5,
            color=C_MUTED,
            zorder=4,
        )


def _er_bus(ax, hub_x: float, from_y: float, bus_y: float, targets: list[tuple[float, float]], label: str = ""):
    """Вертикаль от сущности → горизонтальная шина → вертикали к дочерним."""
    xs = [t[0] for t in targets]
    ax.plot([hub_x, hub_x], [from_y, bus_y], color=C_ARROW, linewidth=1.4, zorder=1)
    ax.plot([min(xs), max(xs)], [bus_y, bus_y], color=C_ARROW, linewidth=1.4, zorder=1)
    for tx, top_y in targets:
        ax.plot([tx, tx], [bus_y, top_y], color=C_ARROW, linewidth=1.4, zorder=1)
        ax.add_patch(
            FancyArrowPatch(
                (tx, top_y),
                (tx, top_y - 0.6),
                arrowstyle="-|>",
                mutation_scale=12,
                color=C_ARROW,
                zorder=1,
            )
        )
    if label:
        ax.text(hub_x + 2.5, (from_y + bus_y) / 2, label, fontsize=8.5, color=C_MUTED, ha="left", va="center", style="italic")


def draw_architecture_layers():
    fig, ax = _new_fig(10, 11)

    # Основная колонка — сверху вниз: симуляция → мост → представление
    cx, bw = 50, 62
    x = cx - bw / 2

    _rounded_box(
        ax, x, 72, bw, 14,
        "Слой симуляции — Rust engine",
        ["Scene::update", "PlatformerMotor · AnimStateMachine · BehaviorTree", "Lua (mlua) · Physics 2D · Audio queue"],
        facecolor=C_SIM,
    )
    _rounded_box(
        ax, x, 50, bw, 12,
        "Слой моста — FFI / контракт v3",
        ["scene_to_engine_json", "scene_create · scene_update · scene_destroy", "scene_set_paused · scene_set_gamepad"],
        facecolor=C_BRIDGE,
    )
    _rounded_box(
        ax, x, 28, bw, 14,
        "Слой представления — Flutter client",
        ["Hub · SceneEditor · GamePlayerScreen", "GameWorldPainter · TilemapLayerPainter"],
        facecolor=C_PRESENT,
    )

    _v_arrow(ax, cx, 72, 62, "JSON v3 → ядро", "right")
    _v_arrow(ax, cx, 50, 42, "позиции · uv_rect · события", "right")

    # Перспектива — отдельно справа, без пересечения стрелок
    _rounded_box(
        ax, 78, 78, 18, 10,
        "Lynx Core",
        ["batch2d", "math (M2)"],
        facecolor=C_INFRA,
        title_size=10,
        body_size=8.5,
    )
    _h_arrow(ax, 78, 72, 83, "перспектива", above=True)

    _save(fig, "architecture_layers.png")


def draw_component_diagram():
    fig, ax = _new_fig(10, 10)

    layers = [
        (78, 16, "ПРЕДСТАВЛЕНИЕ", "SceneEditor · GamePlayerScreen · Painters", C_PRESENT),
        (58, 14, "МОСТ", "engine_bridge · scene_to_engine_json · GamePlayLoader", C_BRIDGE),
        (36, 16, "СИМУЛЯЦИЯ", "scene.rs · platformer.rs · behavior_tree.rs · lua.rs", C_SIM),
    ]
    x, w = 14, 72
    for y, h, title, body, color in layers:
        _rounded_box(ax, x, y, w, h, title, [body], facecolor=color)

    cx = x + w / 2
    _v_arrow(ax, cx, 78, 72, "dt, ввод", "right")
    _v_arrow(ax, cx, 58, 52, "состояние сцены", "right")

    # Инфраструктура — справа от стека, без пересечения с блоками
    _rounded_box(ax, 86, 52, 12, 16, "ИНФРА", ["lynx-core", "batch2d (M2)"], facecolor=C_INFRA, title_size=9, body_size=8)
    ax.plot([86, 80], [60, 60], color=C_ARROW, linewidth=1.2, linestyle="--", zorder=1)
    ax.add_patch(FancyArrowPatch((80, 60), (78, 60), arrowstyle="-|>", mutation_scale=10, color=C_ARROW, zorder=1))
    ax.text(92, 70, "перспектива", fontsize=8, color=C_MUTED, ha="center", rotation=90)

    _save(fig, "component_diagram.png")


def draw_er_diagram():
    fig, ax = _new_fig(12, 8)

    # Верх: Project
    pw, ph = 30, 13
    px = 50 - pw / 2
    _rounded_box(ax, px, 82, pw, ph, "Project", [
        "designWidth, designHeight",
        "startupSceneId, inputMap",
        "tilesets, audioMasterVolume",
    ], facecolor=C_BRIDGE)

    # Центр: Scene
    sw, sh = 30, 14
    sx = 50 - sw / 2
    _rounded_box(ax, sx, 58, sw, sh, "Scene", [
        "formatVersion: 3",
        "objects[], layers[]",
        "tilemapLayers[], rooms[]",
        "animationClips[], extensions[]",
    ], facecolor=C_SIM)

    # Низ: три дочерние сущности — одинаковая ширина и зазор
    cw, ch = 27, 15
    gap = 4
    total = 3 * cw + 2 * gap
    x0 = (100 - total) / 2
    child_specs = [
        (x0, "SceneObject", ["transform, layerId", "properties, scriptPath", "parentId"]),
        (x0 + cw + gap, "TilemapLayer", ["chunks, tile_ids", "collision 0–4", "tilesetId"]),
        (x0 + 2 * (cw + gap), "RoomZone", ["bounds", "camera_min, camera_max"]),
    ]
    centers: list[float] = []
    for cx, title, body in child_specs:
        _rounded_box(ax, cx, 22, cw, ch, title, body, facecolor=C_PRESENT)
        centers.append(cx + cw / 2)

    # Project (низ 82) → Scene (верх 72)
    _v_arrow(ax, 50, 82, 73, "1 : N", "right")

    # Scene (низ 58) → шина → дочерние (верх 37)
    _er_bus(ax, 50, 58, 46, [(c, 37) for c in centers], "1 : N")

    _save(fig, "er_diagram_v3.png")


def draw_play_sequence():
    fig, ax = _new_fig(12, 10)

    actors = [
        (15, "PlayerScreen\n(Flutter)"),
        (35, "GamePlayLoader"),
        (55, "Rust engine"),
        (75, "GameWorldPainter\n(Flutter)"),
    ]
    top, bottom = 88, 12
    for x, name in actors:
        ax.plot([x, x], [bottom, top], color="#BDC3C7", linewidth=1.2, zorder=0)
        ax.plot([x, x], [bottom, top], color=C_BORDER, linewidth=0.6, linestyle=":", zorder=0)
        ax.text(x, 92, name, ha="center", va="bottom", fontsize=9.5, fontweight="bold", color=C_TEXT)

    # Шаги: (from_x, to_x, y, label) — достаточный вертикальный зазор
    steps = [
        (15, 35, 82, "1. load(project.json)"),
        (35, 55, 74, "2. merge autoload"),
        (35, 55, 66, "3. scene_to_engine_json"),
        (55, 55, 58, "4. scene_create"),
        (15, 55, 48, "5. tick(dt), 60 Гц"),
        (55, 55, 40, "6. scene_update(dt)"),
        (55, 75, 32, "7. positions, uv_rect, events"),
        (75, 75, 24, "8. paint()"),
    ]
    for x1, x2, y, label in steps:
        if x1 == x2:
            # self-call: короткая стрелка вправо, без петли
            ax.add_patch(
                FancyArrowPatch(
                    (x2, y),
                    (x2 + 6, y),
                    arrowstyle="-|>",
                    mutation_scale=12,
                    color=C_ARROW,
                    shrinkA=0,
                    shrinkB=0,
                    zorder=2,
                )
            )
            ax.text(x2 + 8, y, label, fontsize=8.5, va="center", ha="left", color=C_TEXT)
        else:
            _h_arrow(ax, x1, x2, y, label, above=True)

    # Рамка цикла
    ax.add_patch(
        FancyBboxPatch(
            (8, 18), 72, 34,
            boxstyle="round,pad=0.3,rounding_size=1",
            linewidth=1,
            edgecolor="#AEB6BF",
            facecolor="none",
            linestyle="--",
            zorder=0,
        )
    )
    ax.text(44, 20, "игровой цикл (каждый кадр)", ha="center", fontsize=8.5, color=C_MUTED, style="italic")
    _save(fig, "play_sequence.png")


def draw_export_flow():
    fig, ax = _new_fig(10, 9)

    _rounded_box(ax, 28, 78, 44, 11, "Единый проект", [
        "project.json + scenes/*.json + assets",
    ], facecolor=C_BRIDGE)
    _v_arrow(ax, 50, 78, 70)

    # Три ветки — равномерно
    branches = [
        (10, 48, 24, 14, "Windows", ["Player.exe", "engine.dll", "game_data/"], C_PRESENT),
        (38, 48, 24, 14, "Web", ["index.html", "WebSceneEngine", "static assets"], C_PRESENT),
        (66, 48, 24, 14, "Android", ["APK", "libengine.so", "game_data/"], C_PRESENT),
    ]
    for bx, by, bw, bh, title, body, color in branches:
        ax.plot([50, bx + bw / 2], [70, by + bh], color=C_ARROW, linewidth=1.3, zorder=1)
        ax.add_patch(
            FancyArrowPatch(
                (bx + bw / 2, by + bh),
                (bx + bw / 2, by + bh - 0.5),
                arrowstyle="-|>",
                mutation_scale=12,
                color=C_ARROW,
                zorder=1,
            )
        )
        _rounded_box(ax, bx, by, bw, bh, title, body, facecolor=color, body_size=8.5)

    _rounded_box(ax, 28, 18, 44, 12, "Три артефакта готовы", [
        "один контент · без правки Lua",
    ], facecolor=C_SIM)
    for bx, _, bw, _, _, _, _ in branches:
        ax.plot([bx + bw / 2, 50], [48, 30], color=C_ARROW, linewidth=1.3, zorder=1)
    ax.add_patch(FancyArrowPatch((50, 30), (50, 30.5), arrowstyle="-|>", mutation_scale=12, color=C_ARROW))

    _save(fig, "export_flow.png")


def draw_ui_editor():
    fig, ax = _new_fig(11, 7)

    _rounded_box(ax, 8, 84, 84, 7, "Панель инструментов", ["Play  ·  Сохранить  ·  Экспорт"], facecolor=C_BRIDGE, title_size=10, body_size=9)

    _rounded_box(ax, 8, 18, 20, 62, "Проект", ["Сцены", "─────────", "▸ Player", "▸ PatrolEnemy", "▸ Camera2D"], facecolor=C_PRESENT, title_size=10, body_size=8.5)
    _rounded_box(ax, 30, 18, 48, 62, "Холст сцены", ["тайлмап · слои · объекты", "сетка чанка 16×16"], facecolor="#FAFAFA", title_size=10, body_size=9)
    _rounded_box(ax, 80, 18, 12, 62, "Инспектор", ["transform", "PlatformerMotor", "AnimSM", "BT JSON"], facecolor=C_PRESENT, title_size=9, body_size=8)

    _save(fig, "ui_editor_desktop.png")


def draw_ui_play():
    fig, ax = _new_fig(10, 6)

    # Корпус «телефона»
    phone = FancyBboxPatch(
        (12, 14), 76, 72,
        boxstyle="round,pad=0.02,rounding_size=2",
        linewidth=2,
        edgecolor=C_BORDER,
        facecolor="#FAFAFA",
        zorder=1,
    )
    ax.add_patch(phone)

    _rounded_box(ax, 18, 38, 64, 40, "Игровая сцена", ["design 960×540 · letterbox"], facecolor="white", title_size=10, body_size=9)
    _rounded_box(ax, 58, 58, 22, 16, "BT overlay", ["● leaf_patrol", "(active)"], facecolor="#E8F8F5", title_size=9, body_size=8.5)

    # Кнопки
    for label, px in [("◀", 22), ("▶", 38), ("⬆", 54)]:
        ax.add_patch(FancyBboxPatch((px, 20), 10, 10, boxstyle="round,pad=0.1", facecolor=C_UI, edgecolor=C_BORDER, zorder=2))
        ax.text(px + 5, 25, label, ha="center", va="center", fontsize=11, zorder=3)

    _save(fig, "ui_play_mobile.png")


def draw_external_placeholder():
    fig, ax = _new_fig(10, 7)

    _rounded_box(ax, 10, 22, 80, 58, "Вставьте макеты из Figma / графического редактора", [
        "1. SceneEditor — панели, холст, инспектор",
        "2. GamePlayerScreen — Play, overlay BT",
        "3. Адаптивные состояния (desktop / mobile)",
        "",
        "В подписи указать: автор дизайна, дата, источник",
    ], facecolor="#F8F9F9", body_size=9.5)

    ax.add_patch(
        FancyBboxPatch(
            (14, 26), 72, 50,
            boxstyle="round,pad=0.02",
            linewidth=1.2,
            edgecolor="#AEB6BF",
            facecolor="none",
            linestyle="--",
            zorder=1,
        )
    )
    ax.text(50, 48, "[ область для PNG / PDF макета ]", ha="center", va="center",
            fontsize=12, color="#95A5A6", style="italic")
    _save(fig, "external_ui_design_placeholder.png")


def main():
    draw_architecture_layers()
    draw_component_diagram()
    draw_er_diagram()
    draw_play_sequence()
    draw_export_flow()
    draw_ui_editor()
    draw_ui_play()
    draw_external_placeholder()
    print("OK - diagrams saved to:", ROOT_OUT, "and", FIGURES_OUT)


if __name__ == "__main__":
    main()
