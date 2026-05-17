"""Слияние LoRA с базой: python -m roza.train merge --base … --adapter … --out …"""
from __future__ import annotations

import argparse
import sys


def merge_main(argv: list[str] | None) -> int:
    argv = argv or []
    p = argparse.ArgumentParser(prog="roza.train merge")
    p.add_argument("--base", required=True, help="HF id или путь к базовой модели")
    p.add_argument("--adapter", type=str, required=True, help="Папка с адаптером PEFT")
    p.add_argument("--out", type=str, required=True, help="Папка для полной модели")
    ns = p.parse_args(argv)

    try:
        import torch
        from peft import PeftModel
        from transformers import AutoModelForCausalLM, AutoTokenizer
    except ImportError as e:
        print(f"Нужны зависимости [train]: {e}", file=sys.stderr)
        return 1

    print("Загрузка базы…", flush=True)
    model = AutoModelForCausalLM.from_pretrained(
        ns.base,
        torch_dtype=torch.bfloat16
        if torch.cuda.is_available() and torch.cuda.is_bf16_supported()
        else torch.float32,
        device_map="auto" if torch.cuda.is_available() else None,
        trust_remote_code=True,
    )
    tok = AutoTokenizer.from_pretrained(ns.base, trust_remote_code=True)
    print("Адаптер…", flush=True)
    model = PeftModel.from_pretrained(model, ns.adapter)
    print("merge_and_unload…", flush=True)
    merged = model.merge_and_unload()
    merged.save_pretrained(ns.out)
    tok.save_pretrained(ns.out)
    print(f"Сохранено: {ns.out}", flush=True)
    return 0
