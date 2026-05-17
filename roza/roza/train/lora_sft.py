"""LoRA SFT по ShareGPT JSONL (поле conversations). Требует pip install -e \".[train]\"."""
from __future__ import annotations

import inspect
from pathlib import Path
from typing import Any


def _log(msg: str, log_file: Path | None) -> None:
    line = msg.rstrip() + "\n"
    print(msg, flush=True)
    if log_file is not None:
        with log_file.open("a", encoding="utf-8") as f:
            f.write(line)


def _format_example(tokenizer: Any, example: dict[str, Any]) -> str:
    conv = example.get("conversations")
    if not isinstance(conv, list):
        return ""
    msgs: list[dict[str, str]] = []
    for turn in conv:
        if not isinstance(turn, dict):
            continue
        f = str(turn.get("from") or "")
        v = str(turn.get("value") or "")
        if f in ("human", "user"):
            msgs.append({"role": "user", "content": v})
        elif f in ("gpt", "assistant"):
            msgs.append({"role": "assistant", "content": v})
    if len(msgs) < 2:
        return ""
    tmpl = getattr(tokenizer, "chat_template", None)
    if tmpl:
        return tokenizer.apply_chat_template(
            msgs,
            tokenize=False,
            add_generation_prompt=False,
        )
    parts: list[str] = []
    for m in msgs:
        tag = "User" if m["role"] == "user" else "Assistant"
        parts.append(f"### {tag}\n{m['content']}")
    return "\n\n".join(parts)


def run_lora_sft(cfg: dict[str, Any], log_file: Path | None) -> None:
    import torch
    from datasets import load_dataset
    from peft import LoraConfig, TaskType
    from transformers import AutoModelForCausalLM, AutoTokenizer
    from trl import SFTTrainer

    try:
        from trl import SFTConfig as TRLTrainingConfig
    except ImportError:
        from transformers import TrainingArguments as TRLTrainingConfig  # type: ignore

    base = cfg["base_model"]
    ds_path = cfg["dataset_path"]
    out_dir = Path(cfg["output_dir"])
    out_dir.mkdir(parents=True, exist_ok=True)

    epochs = float(cfg.get("epochs", 1))
    lr = float(cfg.get("learning_rate", 2e-4))
    lora_r = int(cfg.get("lora_r", 8))
    lora_alpha = int(cfg.get("lora_alpha", 16))
    max_seq = int(cfg.get("max_seq_length", 1024))
    bs = int(cfg.get("per_device_train_batch_size", 1))
    grad_acc = int(cfg.get("gradient_accumulation_steps", 8))
    use_4bit = bool(cfg.get("use_4bit", False))

    _log(f"База: {base}", log_file)
    _log(f"Данные: {ds_path}", log_file)
    _log(f"Выход: {out_dir}", log_file)
    _log(f"CUDA: {torch.cuda.is_available()}", log_file)

    tokenizer = AutoTokenizer.from_pretrained(base, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    model_kw: dict[str, Any] = {"trust_remote_code": True}
    if use_4bit:
        try:
            from transformers import BitsAndBytesConfig

            bnb = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_use_double_quant=True,
                bnb_4bit_quant_type="nf4",
                bnb_4bit_compute_dtype=torch.bfloat16
                if torch.cuda.is_bf16_supported()
                else torch.float16,
            )
            model_kw["quantization_config"] = bnb
            model_kw["device_map"] = "auto"
        except Exception as e:
            _log(f"4-bit недоступен ({e}), гружу в полной точности.", log_file)
            use_4bit = False

    model = AutoModelForCausalLM.from_pretrained(base, **model_kw)
    if use_4bit:
        from peft import prepare_model_for_kbit_training

        model = prepare_model_for_kbit_training(model)

    target_modules = [
        "q_proj",
        "k_proj",
        "v_proj",
        "o_proj",
        "gate_proj",
        "up_proj",
        "down_proj",
    ]
    peft_config = LoraConfig(
        r=lora_r,
        lora_alpha=lora_alpha,
        lora_dropout=0.05,
        bias="none",
        task_type=TaskType.CAUSAL_LM,
        target_modules=target_modules,
    )

    ds = load_dataset("json", data_files=ds_path, split="train")

    def formatting_func(example: dict[str, Any]) -> str:
        return _format_example(tokenizer, example)

    def _row_ok(ex: dict[str, Any]) -> bool:
        return len((formatting_func(ex) or "").strip()) >= 8

    try:
        ds = ds.filter(_row_ok)
    except Exception:
        pass
    if len(ds) == 0:
        raise ValueError("После фильтрации не осталось примеров (проверьте ShareGPT JSONL).")

    cuda = torch.cuda.is_available()
    fp16 = bool(cuda and not torch.cuda.is_bf16_supported())
    bf16 = bool(cuda and torch.cuda.is_bf16_supported())

    ta_kw: dict[str, Any] = {
        "output_dir": str(out_dir),
        "num_train_epochs": epochs,
        "per_device_train_batch_size": bs,
        "gradient_accumulation_steps": grad_acc,
        "learning_rate": lr,
        "logging_steps": max(1, grad_acc),
        "save_strategy": "epoch",
        "save_total_limit": 2,
        "fp16": fp16 and not bf16,
        "bf16": bf16,
        "report_to": "none",
        "optim": "adamw_torch",
        "remove_unused_columns": False,
    }

    sig_cfg = inspect.signature(TRLTrainingConfig.__init__).parameters
    if "max_seq_length" in sig_cfg:
        ta_kw["max_seq_length"] = max_seq
    filtered = {k: v for k, v in ta_kw.items() if k in sig_cfg and k != "self"}
    training_args = TRLTrainingConfig(**filtered)

    tr_sig = inspect.signature(SFTTrainer.__init__).parameters
    tr_kw: dict[str, Any] = {
        "model": model,
        "args": training_args,
        "train_dataset": ds,
        "formatting_func": formatting_func,
        "peft_config": peft_config,
    }
    if "max_seq_length" in tr_sig and "max_seq_length" not in sig_cfg:
        tr_kw["max_seq_length"] = max_seq
    if "processing_class" in tr_sig:
        tr_kw["processing_class"] = tokenizer
    else:
        tr_kw["tokenizer"] = tokenizer

    trainer = SFTTrainer(**tr_kw)
    _log("Старт обучения…", log_file)
    trainer.train()
    trainer.save_model(str(out_dir))
    tokenizer.save_pretrained(str(out_dir))
    _log("Адаптер и токенизатор сохранены.", log_file)
