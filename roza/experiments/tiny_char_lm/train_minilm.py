"""
Учебная «своя» языковая модель: крошечная char-level GRU на CPU.
Не конкурент ChatGPT — только цикл: данные → loss → backward → чекпойнт.

Запуск (нужен PyTorch):
  pip install torch
  python experiments/tiny_char_lm/train_minilm.py --text path/to/corpus.txt --steps 5000

Дальше: увеличивать данные, слои, контекст — и переходить к LoRA поверх открытых LLM (см. OBUCHENIE.md).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import torch
import torch.nn as nn
from torch.optim import AdamW


class TinyCharLM(nn.Module):
    def __init__(self, vocab_size: int, emb: int, hidden: int, layers: int = 1):
        super().__init__()
        self.emb = nn.Embedding(vocab_size, emb)
        self.rnn = nn.GRU(emb, hidden, num_layers=layers, batch_first=True)
        self.head = nn.Linear(hidden, vocab_size)

    def forward(self, x: torch.Tensor, h=None):
        e = self.emb(x)
        out, h = self.rnn(e, h)
        logits = self.head(out)
        return logits, h


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--text", type=Path, required=True, help="UTF-8 текст для обучения")
    p.add_argument("--seq", type=int, default=64, help="длина контекста (символов)")
    p.add_argument("--batch", type=int, default=32)
    p.add_argument("--emb", type=int, default=64)
    p.add_argument("--hidden", type=int, default=128)
    p.add_argument("--layers", type=int, default=1)
    p.add_argument("--lr", type=float, default=3e-3)
    p.add_argument("--steps", type=int, default=3000)
    p.add_argument("--out", type=Path, default=Path("experiments/tiny_char_lm/out"))
    args = p.parse_args()

    raw = args.text.read_text(encoding="utf-8", errors="replace")
    if len(raw) < args.seq * 10:
        raise SystemExit("Слишком мало текста: нужно хотя бы ~10× длина контекста.")

    chars = sorted(set(raw))
    stoi = {ch: i for i, ch in enumerate(chars)}
    itos = {i: ch for ch, i in stoi.items()}
    data = torch.tensor([stoi[c] for c in raw], dtype=torch.long)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = TinyCharLM(len(chars), args.emb, args.hidden, args.layers).to(device)
    opt = AdamW(model.parameters(), lr=args.lr)
    crit = nn.CrossEntropyLoss()

    n = len(data) - args.seq - 1
    args.out.mkdir(parents=True, exist_ok=True)

    model.train()
    for step in range(1, args.steps + 1):
        idx = torch.randint(0, n, (args.batch,))
        xb = torch.stack([data[i : i + args.seq] for i in idx]).to(device)
        yb = torch.stack([data[i + 1 : i + args.seq + 1] for i in idx]).to(device)

        logits, _ = model(xb)
        loss = crit(logits.reshape(-1, len(chars)), yb.reshape(-1))
        opt.zero_grad()
        loss.backward()
        opt.step()

        if step % 200 == 0 or step == 1:
            print(f"step {step:5d}  loss {loss.item():.4f}")

    model.eval()
    with torch.no_grad():
        # короткая выборка «генерации» с жадного декодинга
        seed = data[: args.seq].unsqueeze(0).to(device)
        h = None
        out_chars = []
        cur = seed
        for _ in range(200):
            logits, h = model(cur, h)
            nxt = logits[:, -1, :].argmax(dim=-1, keepdim=True)
            out_chars.append(itos[int(nxt.item())])
            cur = nxt
        sample = "".join(out_chars)
    print("--- sample (greedy, бессмыслица на малых данных — норма) ---")
    print(sample[:500])

    ckpt = {
        "model": model.state_dict(),
        "stoi": stoi,
        "itos": {str(k): v for k, v in itos.items()},
        "config": {
            "emb": args.emb,
            "hidden": args.hidden,
            "layers": args.layers,
            "seq": args.seq,
        },
    }
    path = args.out / "checkpoint.pt"
    torch.save(ckpt, path)
    meta = {
        "checkpoint": str(path.resolve()),
        "vocab": len(chars),
        "train_chars": len(raw),
        "final_loss_approx": float(loss.item()),
    }
    (args.out / "meta.json").write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"Сохранено: {path}")


if __name__ == "__main__":
    main()
