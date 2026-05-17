from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml


@dataclass
class Settings:
    assistant_name: str
    assistant_terms: str
    assistant_think_first: bool
    assistant_swarm_prompt: bool
    llm_backend: str
    hf_local_model_id: str
    hf_local_preset_light: str
    hf_local_preset_strong: str
    hf_local_max_new_tokens: int
    hf_local_device: str
    hf_local_temperature: float
    ollama_base_url: str
    ollama_model: str
    ollama_options: dict[str, Any]
    ollama_stream_chat: bool
    openai_base_url: str
    openai_api_key: str
    openai_model: str
    openai_max_tokens: int | None
    llama_cpp_model_path: Path | None
    llama_cpp_n_ctx: int
    llama_cpp_n_gpu_layers: int
    llama_cpp_n_threads: int
    web_host: str
    web_port: int
    web_cors_origins: list[str]
    desktop_width: int
    desktop_height: int
    desktop_title: str
    desktop_frameless: bool
    desktop_dual_window: bool
    desktop_maximized: bool
    learning_enabled: bool
    learning_log_path: Path
    learning_include_system: bool
    output_strip_thinking: bool
    output_strip_cjk: bool
    output_strip_en_leaks: bool
    ollama_think: bool
    ollama_send_think_param: bool
    voice_provider: str
    edge_tts_voice: str
    voice_require_wake_word: bool
    voice_wake_words: list[str]
    voice_auto_start_listening: bool
    voice_wake_latch_seconds: float
    config_dir: Path
    workspace_roots: list[Path] = field(default_factory=list)
    components_file: Path | None = None
    agent_max_tool_turns: int = 10


def _env(name: str, default: str | None = None) -> str | None:
    v = os.environ.get(name)
    return v if v is not None and v.strip() != "" else default


def load_settings(config_path: Path | None = None) -> Settings:
    path = config_path or Path(os.environ.get("ROZA_CONFIG", "config.yaml"))
    path = path.resolve()
    if not path.is_file():
        raise FileNotFoundError(f"Конфиг не найден: {path}")

    with path.open(encoding="utf-8") as f:
        raw = yaml.safe_load(f) or {}

    assistant = raw.get("assistant") or {}
    llm = raw.get("llm") or {}
    ollama = raw.get("ollama") or {}
    openai = raw.get("openai_compatible") or {}
    llama_yaml = raw.get("llama_cpp") or {}
    hf_local_yaml = raw.get("hf_local") or {}
    workspace = raw.get("workspace") or {}
    agent = raw.get("agent") or {}
    web = raw.get("web") or {}
    desktop = raw.get("desktop") or {}
    learning = raw.get("learning") or {}
    model_output = raw.get("model_output") or {}
    voice = raw.get("voice") or {}

    name = _env("ROZA_NAME", assistant.get("name", "Roza"))
    terms = assistant.get("terms") or ""
    base = _env("ROZA_OLLAMA_URL", ollama.get("base_url", "http://127.0.0.1:11434"))
    model = _env("ROZA_MODEL", ollama.get("model", "deepseek-r1:7b"))

    assert name is not None and base is not None and model is not None

    backend = (_env("ROZA_LLM_BACKEND", llm.get("backend")) or "hf_local").strip().lower()
    if backend not in ("ollama", "openai_compatible", "llama_cpp", "hf_local"):
        backend = "hf_local"

    config_dir = path.parent
    roots_raw = workspace.get("roots") or ["."]
    roots: list[Path] = []
    for r in roots_raw:
        p = Path(r)
        if not p.is_absolute():
            p = (config_dir / p).resolve()
        roots.append(p)

    comp_name = raw.get("components_file", "components.yaml")
    comp_path = Path(comp_name)
    if not comp_path.is_absolute():
        comp_path = (config_dir / comp_path).resolve()
    components_file = comp_path if comp_path.is_file() else None

    max_turns = int(agent.get("max_tool_turns", 10))

    raw_opts = ollama.get("options")
    ollama_options: dict[str, Any] = {}
    if isinstance(raw_opts, dict):
        for k, v in raw_opts.items():
            if v is not None:
                ollama_options[str(k)] = v

    ctx_env = _env("ROZA_NUM_CTX")
    if ctx_env is not None:
        try:
            ollama_options["num_ctx"] = int(ctx_env)
        except ValueError:
            pass
    pred_env = _env("ROZA_NUM_PREDICT")
    if pred_env is not None:
        try:
            ollama_options["num_predict"] = int(pred_env)
        except ValueError:
            pass

    stream_chat = bool(ollama.get("stream_chat", True))
    stream_env = os.environ.get("ROZA_STREAM")
    if stream_env is not None:
        v = stream_env.strip().lower()
        if v in ("0", "false", "no", "off"):
            stream_chat = False
        elif v in ("1", "true", "yes", "on"):
            stream_chat = True

    oa_base = str(openai.get("base_url", "http://127.0.0.1:1234/v1")).rstrip("/")
    oa_key = str(openai.get("api_key", "") or "")
    oa_model = str(openai.get("model") or model).strip()
    oa_max = openai.get("max_tokens")
    openai_max_tokens: int | None
    if oa_max is None or oa_max == "":
        openai_max_tokens = None
    else:
        try:
            openai_max_tokens = int(oa_max)
        except (TypeError, ValueError):
            openai_max_tokens = None

    lp = llama_yaml.get("model_path")
    llama_cpp_model_path: Path | None = None
    if lp:
        pth = Path(str(lp))
        if not pth.is_absolute():
            pth = (config_dir / pth).resolve()
        else:
            pth = pth.resolve()
        llama_cpp_model_path = pth

    llama_cpp_n_ctx = int(llama_yaml.get("n_ctx", 4096))
    llama_cpp_n_gpu_layers = int(llama_yaml.get("n_gpu_layers", 0))
    llama_cpp_n_threads = int(llama_yaml.get("n_threads", 0))

    hf_local_model_id = str(
        hf_local_yaml.get("model_id", "Qwen/Qwen2.5-0.5B-Instruct") or ""
    ).strip()
    hf_local_preset_light = str(
        hf_local_yaml.get("preset_light", hf_local_model_id) or hf_local_model_id
    ).strip()
    hf_local_preset_strong = str(
        hf_local_yaml.get("preset_strong", hf_local_model_id) or hf_local_model_id
    ).strip()
    hf_local_max_new_tokens = int(hf_local_yaml.get("max_new_tokens", 384))
    hf_local_device = str(hf_local_yaml.get("device", "auto") or "auto").strip().lower()
    if hf_local_device not in ("auto", "cpu", "cuda"):
        hf_local_device = "auto"
    try:
        hf_local_temperature = float(hf_local_yaml.get("temperature", 0.35))
    except (TypeError, ValueError):
        hf_local_temperature = 0.35

    web_host = str(web.get("host", "127.0.0.1"))
    web_port = int(web.get("port", 8765))
    raw_cors = web.get("cors_origins")
    web_cors_origins: list[str] = []
    if isinstance(raw_cors, list):
        for o in raw_cors:
            t = str(o).strip()
            if t:
                web_cors_origins.append(t)

    assistant_think_first = bool(assistant.get("think_first", False))
    assistant_swarm_prompt = bool(assistant.get("swarm_prompt", True))

    desktop_width = int(desktop.get("width", 920))
    desktop_height = int(desktop.get("height", 720))
    desktop_title = str(desktop.get("title") or name).strip() or "Roza"
    # По умолчанию — обычное окно ОС (свернуть/развернуть), без полноэкранного старта.
    desktop_frameless = bool(desktop.get("frameless", False))
    desktop_dual_window = bool(desktop.get("dual_window", False))
    desktop_maximized = bool(desktop.get("maximized", False))

    learning_enabled = bool(learning.get("enabled", True))
    learn_path = learning.get("log_path", "data/roza_learn.jsonl")
    lp_learn = Path(str(learn_path))
    if not lp_learn.is_absolute():
        lp_learn = (config_dir / lp_learn).resolve()
    learning_include_system = bool(learning.get("include_system_in_log", False))

    output_strip_thinking = bool(model_output.get("strip_thinking", True))
    output_strip_cjk = bool(model_output.get("strip_cjk", True))
    output_strip_en_leaks = bool(model_output.get("strip_en_leaks", True))

    ollama_think = bool(ollama.get("think", False))
    ollama_send_think_param = bool(ollama.get("send_think_param", True))

    voice_provider = str(voice.get("provider", "edge")).strip().lower()
    if voice_provider not in ("edge", "browser", "none"):
        voice_provider = "edge"
    edge_tts_voice = str(voice.get("edge_voice", "ru-RU-SvetlanaNeural")).strip()

    voice_require_wake_word = bool(voice.get("require_wake_word", True))
    raw_wake = voice.get("wake_words")
    voice_wake_words: list[str] = []
    if isinstance(raw_wake, list):
        for x in raw_wake:
            s = str(x).strip()
            if s:
                voice_wake_words.append(s)
    voice_auto_start_listening = bool(voice.get("auto_start_listening", True))
    try:
        voice_wake_latch_seconds = float(voice.get("wake_latch_seconds", 12))
    except (TypeError, ValueError):
        voice_wake_latch_seconds = 12.0
    voice_wake_latch_seconds = max(3.0, min(voice_wake_latch_seconds, 120.0))

    if not voice_wake_words:
        base = (name or "").strip()
        if base:
            low = base.lower()
            voice_wake_words = [low, low.replace(" ", "")]

    return Settings(
        assistant_name=name.strip(),
        assistant_terms=str(terms).strip(),
        assistant_think_first=assistant_think_first,
        assistant_swarm_prompt=assistant_swarm_prompt,
        llm_backend=backend,
        hf_local_model_id=hf_local_model_id,
        hf_local_preset_light=hf_local_preset_light,
        hf_local_preset_strong=hf_local_preset_strong,
        hf_local_max_new_tokens=max(32, min(hf_local_max_new_tokens, 8192)),
        hf_local_device=hf_local_device,
        hf_local_temperature=hf_local_temperature,
        ollama_base_url=base.rstrip("/"),
        ollama_model=model.strip(),
        ollama_options=ollama_options,
        ollama_stream_chat=stream_chat,
        openai_base_url=oa_base,
        openai_api_key=oa_key,
        openai_model=oa_model,
        openai_max_tokens=openai_max_tokens,
        llama_cpp_model_path=llama_cpp_model_path,
        llama_cpp_n_ctx=max(512, llama_cpp_n_ctx),
        llama_cpp_n_gpu_layers=llama_cpp_n_gpu_layers,
        llama_cpp_n_threads=max(0, llama_cpp_n_threads),
        web_host=web_host,
        web_port=web_port,
        web_cors_origins=web_cors_origins,
        desktop_width=max(360, desktop_width),
        desktop_height=max(400, desktop_height),
        desktop_title=desktop_title,
        desktop_frameless=desktop_frameless,
        desktop_dual_window=desktop_dual_window,
        desktop_maximized=desktop_maximized,
        learning_enabled=learning_enabled,
        learning_log_path=lp_learn,
        learning_include_system=learning_include_system,
        output_strip_thinking=output_strip_thinking,
        output_strip_cjk=output_strip_cjk,
        output_strip_en_leaks=output_strip_en_leaks,
        ollama_think=ollama_think,
        ollama_send_think_param=ollama_send_think_param,
        voice_provider=voice_provider,
        edge_tts_voice=edge_tts_voice,
        voice_require_wake_word=voice_require_wake_word,
        voice_wake_words=voice_wake_words,
        voice_auto_start_listening=voice_auto_start_listening,
        voice_wake_latch_seconds=voice_wake_latch_seconds,
        config_dir=config_dir,
        workspace_roots=roots,
        components_file=components_file,
        agent_max_tool_turns=max(1, min(max_turns, 50)),
    )
