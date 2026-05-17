from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

from roza import __version__
from roza.agent import AgentSession
from roza.assistant import RozaSession
from roza.components import list_components, load_components, run_action
from roza.config import Settings, load_settings


def _llm_error_hint(settings: Settings) -> str:
    b = settings.llm_backend
    if b == "ollama":
        return (
            f"Запустите Ollama и проверьте модель: ollama pull {settings.ollama_model}"
        )
    if b == "openai_compatible":
        return (
            "Проверьте openai_compatible.base_url и что локальный сервер запущен "
            "(LM Studio, vLLM и т.п.)."
        )
    if b == "hf_local":
        return (
            'Локальная HF-модель: pip install -e ".[hf]" (или ".[train]"), '
            "первый запрос скачает веса с Hugging Face (нужен интернет)."
        )
    return (
        "Проверьте llama_cpp.model_path к .gguf и установку: pip install llama-cpp-python"
    )


def _llm_startup_hint(settings: Settings) -> str:
    if settings.llm_backend == "ollama":
        return "Ollama должна быть запущена; модель: `ollama pull …`."
    if settings.llm_backend == "openai_compatible":
        return f"Сервер чата: {settings.openai_base_url}"
    if settings.llm_backend == "hf_local":
        return f"HF локально: {settings.hf_local_model_id}"
    return f"GGUF: {settings.llama_cpp_model_path}"


def _cmd_chat(settings, query: str | None, accept_offer: bool) -> int:
    name = settings.assistant_name
    model = settings.ollama_model
    if query is not None:
        session = RozaSession(settings)
        q = query.strip()
        try:
            if settings.ollama_stream_chat:
                print(f"{name}: ", end="", flush=True)

                def _delta(c: str) -> None:
                    print(c, end="", flush=True)

                session.ask(q, stream=True, on_delta=_delta)
                print()
            else:
                print(session.ask(q, stream=False))
        except Exception as e:
            print()
            hint = _llm_error_hint(settings)
            print(f"Ошибка: {e}\n{hint}", file=sys.stderr)
            if session.history and session.history[-1].get("role") == "user":
                session.history.pop()
            return 1
        return 0

    print(f"{name} (модель: {model}) — выход: /exit, /reset, /name")
    if accept_offer:
        print("Условия использования: OFERTA.md в корне проекта.\n")
    print(_llm_startup_hint(settings) + "\n")

    session = RozaSession(settings)
    while True:
        try:
            line = input(f"{name}> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return 0
        if not line:
            continue
        if line == "/exit":
            return 0
        if line == "/reset":
            session.reset()
            print("(диалог сброшен)")
            continue
        if line == "/name":
            print(name)
            continue
        try:
            if settings.ollama_stream_chat:
                print(f"{name}: ", end="", flush=True)

                def _delta(c: str) -> None:
                    print(c, end="", flush=True)

                out = session.ask(line, stream=True, on_delta=_delta)
                print("\n")
            else:
                out = session.ask(line, stream=False)
                print(f"{name}: {out}\n")
        except Exception as e:
            print(f"Ошибка: {e}", file=sys.stderr)
            session.history.pop()
            continue
    return 0


def _cmd_agent(settings, accept_offer: bool) -> int:
    name = settings.assistant_name
    model = settings.ollama_model
    print(f"{name} — режим агента (модель: {model}).")
    print("Модель может вызывать инструменты строкой ROZA_TOOL: {{...}} — см. системный промпт.")
    print("Команды: /exit, /reset. Условия: OFERTA.md\n")
    if accept_offer:
        print("(Напоминание: OFERTA.md)\n")

    session = AgentSession(settings)
    while True:
        try:
            line = input(f"{name}[agent]> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return 0
        if not line:
            continue
        if line == "/exit":
            return 0
        if line == "/reset":
            session.reset()
            print("(диалог сброшен)")
            continue
        try:
            out = session.ask(line)
        except Exception as e:
            print(f"Ошибка: {e}", file=sys.stderr)
            if session.history and session.history[-1].get("role") == "user":
                session.history.pop()
            continue
        print(f"{name}: {out}\n")
    return 0


def _cmd_comp(settings, comp_action: str, cid: str | None, action: str | None) -> int:
    reg = load_components(settings.components_file)
    if not reg:
        print("Нет components.yaml или он пуст. См. components.example.yaml", file=sys.stderr)
        return 1
    if comp_action == "list":
        for c in list_components(reg):
            acts = ", ".join(sorted(c.actions)) if c.actions else ""
            print(f"{c.cid}\t{c.title}\t[{acts}]")
        return 0
    if comp_action == "run":
        if not cid or not action:
            print("Нужны --id и --action", file=sys.stderr)
            return 1
        print(run_action(reg, cid, action))
        return 0
    return 1


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass

    argv = sys.argv[1:]
    if not argv:
        argv = ["companion"]

    # Глобальные флаги до подкоманды: roza -c cfg.yaml chat ...
    config_path: Path | None = None
    filtered: list[str] = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("-c", "--config") and i + 1 < len(argv):
            config_path = Path(argv[i + 1])
            i += 2
            continue
        if a in ("--version", "-V"):
            print(__version__)
            return 0
        filtered.append(a)
        i += 1

    if not filtered:
        filtered = ["companion"]

    head, tail = filtered[0], filtered[1:]
    if head in (
        "chat",
        "agent",
        "comp",
        "eval",
        "web",
        "desktop",
        "companion",
        "shortcut",
        "train",
    ):
        sub = head
        rest = tail
    else:
        sub = "chat"
        rest = filtered

    if sub == "companion":
        argparse.ArgumentParser(prog="roza companion").parse_args(rest)
        from roza.companion_launcher import run_companion

        return run_companion()

    try:
        settings = load_settings(config_path)
    except FileNotFoundError as e:
        print(e, file=sys.stderr)
        return 1

    if sub == "chat":
        p = argparse.ArgumentParser(prog="roza chat", add_help=True)
        p.add_argument("-q", "--query", type=str, default=None)
        p.add_argument(
            "--accept-offer",
            action="store_true",
            help="Показать напоминание об OFERTA.md",
        )
        ns = p.parse_args(rest)
        return _cmd_chat(settings, ns.query, ns.accept_offer)

    if sub == "agent":
        p = argparse.ArgumentParser(prog="roza agent")
        p.add_argument("--accept-offer", action="store_true")
        ns = p.parse_args(rest)
        return _cmd_agent(settings, ns.accept_offer)

    if sub == "comp":
        p = argparse.ArgumentParser(prog="roza comp")
        p.add_argument("comp_action", choices=["list", "run"])
        p.add_argument("--id", type=str, default=None)
        p.add_argument("--action", type=str, default=None)
        ns = p.parse_args(rest)
        return _cmd_comp(settings, ns.comp_action, ns.id, ns.action)

    if sub == "eval":
        p = argparse.ArgumentParser(prog="roza eval")
        p.add_argument(
            "-t",
            "--tasks",
            type=Path,
            default=None,
            help="Путь к YAML с задачами (по умолчанию eval/code_tasks.yaml)",
        )
        ns = p.parse_args(rest)
        from roza.eval.__main__ import run_eval

        tasks_path = ns.tasks
        if tasks_path is None:
            tasks_path = (settings.config_dir / "eval" / "code_tasks.yaml").resolve()
        else:
            tasks_path = tasks_path.resolve()
        if not tasks_path.is_file():
            print(f"Файл задач не найден: {tasks_path}", file=sys.stderr)
            return 1
        return run_eval(settings, tasks_path)

    if sub == "web":
        p = argparse.ArgumentParser(prog="roza web")
        p.add_argument(
            "--host",
            type=str,
            default=None,
            help="Переопределить web.host из config.yaml",
        )
        p.add_argument(
            "--port",
            type=int,
            default=None,
            help="Переопределить web.port",
        )
        ns = p.parse_args(rest)
        if config_path is not None:
            os.environ["ROZA_CONFIG"] = str(config_path.resolve())
        try:
            import uvicorn
        except ImportError as e:
            print(
                "Нужен uvicorn: pip install uvicorn[standard] fastapi",
                file=sys.stderr,
            )
            raise SystemExit(1) from e
        from roza.web.app import create_app

        host = ns.host or settings.web_host
        port = ns.port if ns.port is not None else settings.web_port
        print(f"Roza UI: http://{host}:{port}/  (Ctrl+C — остановить)")
        uvicorn.run(
            create_app(),
            host=host,
            port=port,
            log_level="warning",
            access_log=False,
        )
        return 0

    if sub == "desktop":
        argparse.ArgumentParser(prog="roza desktop").parse_args(rest)
        if config_path is not None:
            os.environ["ROZA_CONFIG"] = str(config_path.resolve())
        try:
            from roza.web.desktop_launcher import run_desktop_window

            run_desktop_window(settings)
        except RuntimeError as e:
            print(str(e), file=sys.stderr)
            return 1
        return 0

    if sub == "train":
        from roza.train.cli import main as train_cli_main

        return train_cli_main(rest)

    if sub == "shortcut":
        p = argparse.ArgumentParser(prog="roza shortcut")
        p.add_argument(
            "--out",
            type=Path,
            default=None,
            help="Папка для Roza.bat и Roza.lnk (по умолчанию — рабочий стол)",
        )
        p.add_argument(
            "--portable-bundle",
            type=Path,
            default=None,
            metavar="DIR",
            help="Корень переносной сборки: Run-Roza.bat + Roza.lnk (.venv уже создан)",
        )
        ns = p.parse_args(rest)

        from roza.shortcut import install_desktop_launcher, install_portable_shortcuts

        if ns.portable_bundle is not None:
            bat, lnk = install_portable_shortcuts(ns.portable_bundle)
            print(f"Portable (консоль при ошибке): {bat}")
            print(f"Без чёрного окна: Run-Roza-quiet.vbs")
            if lnk:
                print(f"Ярлык (без терминала): {lnk}")
            else:
                print("(Roza.lnk не создан — ошибка PowerShell; используйте Run-Roza-quiet.vbs)")
            return 0

        bat, comp_bat, lnk, vbs = install_desktop_launcher(settings, config_path, output_dir=ns.out)
        print(f"С консолью (Python desktop): {bat}")
        print(f"Только Companion (иконка розы): {comp_bat}")
        print(f"Без терминала (Python desktop): {vbs}")
        if lnk:
            print(f"Ярлык (рекомендуется): {lnk}")
        else:
            print("(Roza.lnk не создан; используйте Roza-quiet.vbs)")
        print('Нужен пакет для Python desktop: pip install pywebview  или  pip install -e ".[desktop]"')
        print("Или в терминале: roza companion  — только приложение с логотипом (Companion).")
        return 0

    print(f"Неизвестная подкоманда: {sub}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
