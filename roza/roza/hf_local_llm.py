"""Локальный чат через Hugging Face Transformers (без Ollama и без GGUF)."""
from __future__ import annotations

import threading
import types
from collections.abc import Callable
from typing import Any

from roza.config import Settings
from roza.llm_usage import merge_last_llm_usage
from roza.text_sanitize import sanitize_model_output

_bundle: dict[str, Any] = {}


def _patch_huggingface_hub_pep604_unions() -> None:
    """Совместимость: strict-dataclass в huggingface_hub до недавних версий не регистрирует types.UnionType.

    Поля вида ``import_name: str | None`` дают «Unsupported type for field …: str | None».
    Регистрируем тот же валидатор, что и для ``typing.Union`` (см. upstream dataclasses.py).
    """
    try:
        import huggingface_hub.dataclasses as hfd  # noqa: PLC0415
    except ImportError:
        return
    if getattr(hfd, "_roza_pep604_union_patch", False):
        return
    union_type = getattr(types, "UnionType", None)
    if union_type is None:
        setattr(hfd, "_roza_pep604_union_patch", True)
        return
    validators = getattr(hfd, "_BASIC_TYPE_VALIDATORS", None)
    validate_union = getattr(hfd, "_validate_union", None)
    if not isinstance(validators, dict) or validate_union is None:
        setattr(hfd, "_roza_pep604_union_patch", True)
        return
    if validators.get(union_type) is not validate_union:
        validators[union_type] = validate_union
    setattr(hfd, "_roza_pep604_union_patch", True)


_patch_huggingface_hub_pep604_unions()

_hf_model_id_override: str | None = None


def set_hf_local_model_id_override(model_id: str | None) -> None:
    """Переопределить HF model_id до перезапуска процесса (очищает кэш весов)."""
    global _hf_model_id_override, _bundle
    v = (model_id or "").strip() or None
    _hf_model_id_override = v
    _bundle = {}


def effective_hf_model_id(settings: Settings) -> str:
    if _hf_model_id_override:
        return _hf_model_id_override
    return settings.hf_local_model_id.strip()


def _hf_import_error() -> RuntimeError:
    return RuntimeError(
        'Для llm.backend: hf_local установите зависимости: pip install -e ".[hf]" '
        "(или .[train], там же torch и transformers)."
    )


def _resolve_device(pref: str) -> Any:
    import torch

    p = (pref or "auto").strip().lower()
    if p == "cpu":
        return torch.device("cpu")
    if p == "cuda":
        if torch.cuda.is_available():
            return torch.device("cuda")
        return torch.device("cpu")
    if torch.cuda.is_available():
        return torch.device("cuda")
    return torch.device("cpu")


def _from_pretrained_causal(model_id: str, use_cuda: bool) -> Any:
    import torch
    from transformers import AutoModelForCausalLM

    if use_cuda:
        dtype = torch.bfloat16 if torch.cuda.is_bf16_supported() else torch.float16
        try:
            return AutoModelForCausalLM.from_pretrained(
                model_id,
                trust_remote_code=True,
                dtype=dtype,
                device_map="auto",
            )
        except TypeError:
            return AutoModelForCausalLM.from_pretrained(
                model_id,
                trust_remote_code=True,
                torch_dtype=dtype,
                device_map="auto",
            )
    try:
        return AutoModelForCausalLM.from_pretrained(
            model_id,
            trust_remote_code=True,
            dtype=torch.float32,
        )
    except TypeError:
        return AutoModelForCausalLM.from_pretrained(
            model_id,
            trust_remote_code=True,
            torch_dtype=torch.float32,
        )


def _load(settings: Settings) -> tuple[Any, Any, Any]:
    global _bundle
    try:
        from transformers import AutoTokenizer
    except ImportError as e:
        raise _hf_import_error() from e

    import torch

    model_id = effective_hf_model_id(settings)
    if not model_id:
        raise RuntimeError("hf_local: пустой hf_local.model_id в config.yaml")

    key = f"{model_id}|{settings.hf_local_device}"
    if _bundle.get("key") == key and _bundle.get("model") is not None:
        return _bundle["model"], _bundle["tokenizer"], _bundle["device"]

    device = _resolve_device(settings.hf_local_device)
    try:
        tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)
        if tokenizer.pad_token is None:
            tokenizer.pad_token = tokenizer.eos_token

        if device.type == "cuda":
            model = _from_pretrained_causal(model_id, use_cuda=True)
        else:
            model = _from_pretrained_causal(model_id, use_cuda=False)
            model = model.to(device).eval()
    except Exception as e:
        raise RuntimeError(
            f"Не удалось загрузить HF-модель «{model_id}»: {e}\n"
            "Если загрузка прервалась (Ctrl+C / сеть), удалите неполные файлы в кэше "
            "Hugging Face (папка hub в кэше HF, см. переменная HF_HOME) и запустите снова."
        ) from e

    dev = next(model.parameters()).device
    _bundle = {"key": key, "model": model, "tokenizer": tokenizer, "device": dev}
    return model, tokenizer, dev


def hf_local_complete(
    settings: Settings,
    messages: list[dict[str, str]],
    *,
    stream: bool,
    on_delta: Callable[[str], None] | None,
    timeout: float,
) -> str:
    import torch

    del timeout
    model, tokenizer, device = _load(settings)
    max_new = max(32, min(settings.hf_local_max_new_tokens, 8192))
    temp = max(0.05, min(settings.hf_local_temperature, 2.0))

    try:
        encoded = tokenizer.apply_chat_template(
            messages,
            add_generation_prompt=True,
            return_tensors="pt",
        )
    except Exception as e:
        raise RuntimeError(
            f"Модель не поддерживает chat_template для диалога ({settings.hf_local_model_id}): {e}"
        ) from e

    # Transformers 5+: return_tensors="pt" даёт BatchEncoding, не Tensor
    if isinstance(encoded, torch.Tensor):
        input_ids = encoded
        attn = torch.ones_like(input_ids, dtype=torch.long)
    else:
        input_ids = encoded["input_ids"]
        attn = encoded["attention_mask"] if "attention_mask" in encoded else None
        if attn is None:
            attn = torch.ones_like(input_ids, dtype=torch.long)

    input_ids = input_ids.to(device)
    attn = attn.to(device)
    eos = tokenizer.eos_token_id
    if eos is None:
        eos = getattr(model.config, "eos_token_id", None)

    gen_kw: dict[str, Any] = {
        "input_ids": input_ids,
        "attention_mask": attn,
        "max_new_tokens": max_new,
        "do_sample": True,
        "temperature": temp,
        "top_p": 0.9,
        "pad_token_id": tokenizer.pad_token_id,
    }
    if eos is not None:
        gen_kw["eos_token_id"] = eos

    if stream and on_delta is not None:
        try:
            from transformers import TextIteratorStreamer
        except ImportError as e:
            raise _hf_import_error() from e

        streamer = TextIteratorStreamer(
            tokenizer, skip_prompt=True, skip_special_tokens=True
        )
        gen_kw["streamer"] = streamer
        thread = threading.Thread(target=lambda: model.generate(**gen_kw))
        thread.start()
        parts: list[str] = []
        for text in streamer:
            parts.append(text)
            on_delta(text)
        thread.join()
        out = "".join(parts).strip()
        return sanitize_model_output(out, settings)

    with torch.inference_mode():
        out_ids = model.generate(**gen_kw)

    prompt_len = input_ids.shape[1]
    gen = out_ids[0, prompt_len:]
    text = tokenizer.decode(gen, skip_special_tokens=True).strip()
    merge_last_llm_usage(
        {
            "prompt_tokens": int(prompt_len),
            "completion_tokens": int(gen.shape[0]),
            "total_tokens": int(prompt_len + gen.shape[0]),
            "source": "hf_local",
        },
    )
    return sanitize_model_output(text, settings)


def hf_local_deps_available() -> bool:
    try:
        import torch  # noqa: F401
        import transformers  # noqa: F401

        return True
    except ImportError:
        return False
