from __future__ import annotations

import json
import time
from collections.abc import Callable
from typing import Any

import httpx

from roza.config import Settings
from roza.hf_local_llm import hf_local_complete
from roza.llm_usage import merge_last_llm_usage
from roza.text_sanitize import sanitize_model_output

_http: httpx.Client | None = None


def _get_http() -> httpx.Client:
    global _http
    if _http is None:
        _http = httpx.Client(
            timeout=httpx.Timeout(600.0, connect=30.0),
            limits=httpx.Limits(max_keepalive_connections=8, keepalive_expiry=120.0),
        )
    return _http


def _ollama_raise_http(settings: Settings, e: httpx.HTTPStatusError) -> None:
    sc = e.response.status_code
    snippet = ""
    try:
        snippet = (e.response.text or "")[:240]
    except Exception:
        pass
    model = settings.ollama_model
    if sc == 503:
        msg = (
            "Ollama ответила 503 (занята или модель ещё грузится). "
            "Подождите 30–90 с, перезапустите Ollama в трее; затем: "
            f"ollama run {model}. Если ошибки повторяются — в config.yaml поставьте "
            "ollama.stream_chat: false или send_think_param: false."
        )
    elif sc == 502:
        msg = "Шлюз вернул 502 — Ollama не отвечает, перезапустите службу Ollama."
    else:
        msg = f"Ollama: HTTP {sc}. {snippet}".strip()
    raise RuntimeError(msg) from e


def _ollama_raise_request(settings: Settings, e: httpx.RequestError) -> None:
    raise RuntimeError(
        f"Нет связи с Ollama ({settings.ollama_base_url}): {e!s}. "
        "Убедитесь, что Ollama запущена и порт совпадает с ollama.base_url в config.yaml."
    ) from e


def _ollama_complete(
    settings: Settings,
    messages: list[dict[str, str]],
    *,
    stream: bool,
    on_delta: Callable[[str], None] | None,
    timeout: float,
) -> str:
    url = f"{settings.ollama_base_url}/api/chat"
    payload: dict[str, Any] = {
        "model": settings.ollama_model,
        "messages": messages,
        "stream": stream,
    }
    if settings.ollama_send_think_param:
        payload["think"] = bool(settings.ollama_think)
    opts = settings.ollama_options
    if opts:
        payload["options"] = opts

    client = _get_http()
    attempts = 4
    backoff = 1.25

    if not stream:
        last_http: httpx.HTTPStatusError | None = None
        for attempt in range(attempts):
            try:
                r = client.post(url, json=payload, timeout=timeout)
                r.raise_for_status()
                data = r.json()
                msg = data.get("message") or {}
                content = msg.get("content")
                if not content:
                    raise RuntimeError(f"Пустой ответ Ollama: {data!r}")
                pe = data.get("prompt_eval_count")
                ec = data.get("eval_count")
                if isinstance(pe, (int, float)) or isinstance(ec, (int, float)):
                    pi, ci = int(pe or 0), int(ec or 0)
                    merge_last_llm_usage(
                        {
                            "prompt_tokens": pi,
                            "completion_tokens": ci,
                            "total_tokens": pi + ci,
                            "source": "ollama",
                        },
                    )
                return sanitize_model_output(str(content).strip(), settings)
            except httpx.HTTPStatusError as e:
                last_http = e
                if e.response.status_code in (502, 503) and attempt < attempts - 1:
                    time.sleep(backoff * (attempt + 1))
                    continue
                _ollama_raise_http(settings, e)
            except httpx.RequestError as e:
                if attempt < attempts - 1:
                    time.sleep(backoff * (attempt + 1))
                    continue
                _ollama_raise_request(settings, e)
        if last_http is not None:
            _ollama_raise_http(settings, last_http)
        raise RuntimeError("Ollama: не удалось получить ответ")

    parts: list[str] = []
    last_http = None
    for attempt in range(attempts):
        try:
            with client.stream("POST", url, json=payload, timeout=timeout) as r:
                r.raise_for_status()
                for line in r.iter_lines():
                    if not line:
                        continue
                    try:
                        data = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    if data.get("done"):
                        break
                    msg = data.get("message") or {}
                    chunk = msg.get("content") or ""
                    if chunk:
                        parts.append(chunk)
                        if on_delta is not None:
                            on_delta(chunk)
            out = "".join(parts).strip()
            if not out:
                raise RuntimeError("Пустой потоковый ответ Ollama")
            return sanitize_model_output(out, settings)
        except httpx.HTTPStatusError as e:
            last_http = e
            parts.clear()
            if e.response.status_code in (502, 503) and attempt < attempts - 1:
                time.sleep(backoff * (attempt + 1))
                continue
            _ollama_raise_http(settings, e)
        except httpx.RequestError as e:
            parts.clear()
            if attempt < attempts - 1:
                time.sleep(backoff * (attempt + 1))
                continue
            _ollama_raise_request(settings, e)
    if last_http is not None:
        _ollama_raise_http(settings, last_http)
    raise RuntimeError("Ollama: не удалось получить потоковый ответ")


def _openai_compatible_complete(
    settings: Settings,
    messages: list[dict[str, str]],
    *,
    stream: bool,
    on_delta: Callable[[str], None] | None,
    timeout: float,
) -> str:
    base = settings.openai_base_url.rstrip("/")
    url = f"{base}/chat/completions"
    headers = {"Content-Type": "application/json"}
    if settings.openai_api_key:
        headers["Authorization"] = f"Bearer {settings.openai_api_key}"

    max_tok = settings.openai_max_tokens
    body: dict[str, Any] = {
        "model": settings.openai_model,
        "messages": messages,
        "stream": stream,
    }
    if max_tok is not None:
        body["max_tokens"] = max_tok

    client = _get_http()
    if not stream:
        r = client.post(url, json=body, headers=headers, timeout=timeout)
        r.raise_for_status()
        data = r.json()
        choices = data.get("choices") or []
        if not choices:
            raise RuntimeError(f"Пустой ответ API: {data!r}")
        msg = choices[0].get("message") or {}
        content = msg.get("content") or ""
        if not content:
            raise RuntimeError(f"Нет текста в ответе: {data!r}")
        usage = data.get("usage")
        if isinstance(usage, dict):
            snap: dict[str, Any] = {}
            for k in ("prompt_tokens", "completion_tokens", "total_tokens"):
                v = usage.get(k)
                if isinstance(v, (int, float)):
                    snap[k] = int(v)
            if snap:
                snap["source"] = "openai_compatible"
                merge_last_llm_usage(snap)
        return sanitize_model_output(str(content).strip(), settings)

    parts: list[str] = []
    with client.stream("POST", url, json=body, headers=headers, timeout=timeout) as r:
        r.raise_for_status()
        for line in r.iter_lines():
            if not line:
                continue
            if line.startswith("data: "):
                line = line[6:]
            if line.strip() == "[DONE]":
                break
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue
            for ch in data.get("choices") or []:
                delta = ch.get("delta") or {}
                chunk = delta.get("content") or ""
                if chunk:
                    parts.append(chunk)
                    if on_delta is not None:
                        on_delta(chunk)
    out = "".join(parts).strip()
    if not out:
        raise RuntimeError("Пустой потоковый ответ OpenAI-совместимого API")
    return sanitize_model_output(out, settings)


_llama: Any = None
_llama_path: str | None = None


def _get_llama(settings: Settings):
    global _llama, _llama_path
    path = settings.llama_cpp_model_path
    if path is None or not path.is_file():
        raise FileNotFoundError(
            "llm.backend=llama_cpp: укажите существующий llama_cpp.model_path к .gguf и установите llama-cpp-python"
        )
    key = str(path.resolve())
    if _llama is not None and _llama_path == key:
        return _llama
    try:
        from llama_cpp import Llama
    except ImportError as e:
        raise RuntimeError(
            "Нужен пакет llama-cpp-python: pip install llama-cpp-python"
        ) from e
    kw: dict[str, Any] = {
        "model_path": key,
        "n_ctx": settings.llama_cpp_n_ctx,
        "n_gpu_layers": settings.llama_cpp_n_gpu_layers,
        "verbose": False,
    }
    if settings.llama_cpp_n_threads > 0:
        kw["n_threads"] = settings.llama_cpp_n_threads
    _llama = Llama(**kw)
    _llama_path = key
    return _llama


def _llama_cpp_complete(
    settings: Settings,
    messages: list[dict[str, str]],
    *,
    stream: bool,
    on_delta: Callable[[str], None] | None,
    timeout: float,
) -> str:
    del timeout  # llama-cpp использует свой цикл
    llm = _get_llama(settings)
    max_tokens = None
    if settings.ollama_options and "num_predict" in settings.ollama_options:
        try:
            max_tokens = int(settings.ollama_options["num_predict"])
        except (TypeError, ValueError):
            max_tokens = 512
    if max_tokens is None:
        max_tokens = 2048

    out = llm.create_chat_completion(
        messages=messages,
        stream=stream,
        max_tokens=max_tokens,
    )
    if not stream:
        data = out
        choices = data.get("choices") or []
        if not choices:
            raise RuntimeError(f"Пустой ответ llama.cpp: {data!r}")
        msg = choices[0].get("message") or {}
        content = msg.get("content") or ""
        usage = data.get("usage") if isinstance(data, dict) else None
        if isinstance(usage, dict):
            snap: dict[str, Any] = {}
            for k in ("prompt_tokens", "completion_tokens", "total_tokens"):
                v = usage.get(k)
                if isinstance(v, (int, float)):
                    snap[k] = int(v)
            if snap:
                snap["source"] = "llama_cpp"
                merge_last_llm_usage(snap)
        return sanitize_model_output(str(content).strip(), settings)

    parts: list[str] = []
    for chunk in out:
        choices = chunk.get("choices") or []
        for ch in choices:
            delta = ch.get("delta") or {}
            c = delta.get("content") or ""
            if c:
                parts.append(c)
                if on_delta is not None:
                    on_delta(c)
    text = "".join(parts).strip()
    if not text:
        raise RuntimeError("Пустой потоковый ответ llama.cpp")
    return sanitize_model_output(text, settings)


def chat_completion(
    settings: Settings,
    messages: list[dict[str, str]],
    *,
    stream: bool = False,
    on_delta: Callable[[str], None] | None = None,
    timeout: float = 600.0,
) -> str:
    """Унифицированный вызов модели в зависимости от settings.llm_backend."""
    b = settings.llm_backend
    if b == "ollama":
        return _ollama_complete(settings, messages, stream=stream, on_delta=on_delta, timeout=timeout)
    if b == "openai_compatible":
        return _openai_compatible_complete(
            settings, messages, stream=stream, on_delta=on_delta, timeout=timeout
        )
    if b == "llama_cpp":
        return _llama_cpp_complete(settings, messages, stream=stream, on_delta=on_delta, timeout=timeout)
    if b == "hf_local":
        from roza.hf_local_llm import hf_local_deps_available

        if not hf_local_deps_available():
            raise RuntimeError(
                "Локальная модель на сервере не настроена. "
                "Попробуйте позже или откройте приложение Roza для Windows."
            )
        return hf_local_complete(settings, messages, stream=stream, on_delta=on_delta, timeout=timeout)
    raise ValueError(f"Неизвестный llm.backend: {b}")
