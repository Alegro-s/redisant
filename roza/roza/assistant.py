from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass, field

from roza.config import Settings
from roza.learning import log_turn
from roza.llm import chat_completion


def build_system_content(settings: Settings) -> str:
    s = settings
    base = (
        f"Ты — {s.assistant_name}, личный локальный ассистент пользователя. "
        "Ты работаешь только в рамках запросов пользователя и его правил. "
        "Не представляйся иначе и не используй другие имена.\n\n"
        "Формат ответа: только русский язык, без английских слов внутри русских фраз. "
        "Не начинай ответ с пересказа или кривого повтора вопроса пользователя — сразу отвечай по сути. "
        "На приветствия и «как дела» отвечай коротко и естественно, 1–3 предложения."
    )
    if s.assistant_swarm_prompt:
        base += (
            "\n\nДля нетривиальных задач действуй как координатор небольшого «роя»: "
            "сначала мысленно разложи цель на шаги, проверь зависимости и риски, "
            "затем давай решение (код, текст, вызов инструментов) последовательно и согласованно."
        )
    if s.assistant_terms:
        return f"{base}\n\nПравила пользователя:\n{s.assistant_terms}"
    return base


@dataclass
class RozaSession:
    settings: Settings
    history: list[dict[str, str]] = field(default_factory=list)

    def __post_init__(self) -> None:
        system = build_system_content(self.settings)
        self.history = [{"role": "system", "content": system}]

    def ask(
        self,
        user_text: str,
        *,
        stream: bool | None = None,
        on_delta: Callable[[str], None] | None = None,
    ) -> str:
        use_stream = self.settings.ollama_stream_chat if stream is None else stream
        user_text = user_text.strip()
        if not user_text:
            return ""

        if self.settings.assistant_think_first:
            plan_msgs = [
                self.history[0],
                {
                    "role": "user",
                    "content": (
                        f"{user_text}\n\n"
                        "[Внутренний этап] Только краткий план решения (до 15 строк): "
                        "шаги, проверки, структура ответа. Без приветствий и без полного финального "
                        "ответа пользователю."
                    ),
                },
            ]
            plan = chat_completion(
                self.settings,
                plan_msgs,
                stream=False,
                on_delta=None,
            )
            final_msgs = self.history + [
                {"role": "user", "content": user_text},
                {"role": "assistant", "content": plan.strip()},
                {
                    "role": "user",
                    "content": (
                        "Используя план выше, дай пользователю полный итоговый ответ на исходный запрос. "
                        "Не повторяй план дословно, если достаточно сразу дать результат."
                    ),
                },
            ]
            reply = chat_completion(
                self.settings,
                final_msgs,
                stream=use_stream,
                on_delta=on_delta,
            )
            self.history.append({"role": "user", "content": user_text})
            self.history.append({"role": "assistant", "content": reply})
        else:
            self.history.append({"role": "user", "content": user_text})
            reply = chat_completion(
                self.settings,
                self.history,
                stream=use_stream,
                on_delta=on_delta,
            )
            self.history.append({"role": "assistant", "content": reply})

        sys_log = (
            build_system_content(self.settings)
            if self.settings.learning_include_system
            else None
        )
        log_turn(
            self.settings,
            user_text,
            reply,
            source="chat",
            system_content=sys_log,
        )
        return reply

    def reset(self) -> None:
        self.__post_init__()
