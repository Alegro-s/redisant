from __future__ import annotations

from dataclasses import dataclass, field

from roza.assistant import build_system_content
from roza.llm import chat_completion
from roza.config import Settings
from roza.learning import log_turn
from roza.tools import execute_tool, extract_tool_line, tool_schema_description


@dataclass
class AgentSession:
    settings: Settings
    history: list[dict[str, str]] = field(default_factory=list)

    def __post_init__(self) -> None:
        system = build_system_content(self.settings)
        system = f"{system}\n\n{tool_schema_description(self.settings)}"
        self.history = [{"role": "system", "content": system}]

    def reset(self) -> None:
        self.__post_init__()

    def ask(self, user_text: str, *, stream: bool = False) -> str:
        """stream игнорируется (агент парсит ROZA_TOOL — только полный ответ)."""
        del stream
        self.history.append({"role": "user", "content": user_text})
        turns = 0
        max_turns = self.settings.agent_max_tool_turns

        while turns < max_turns:
            turns += 1
            reply = chat_completion(
                self.settings,
                self.history,
                stream=False,
            )
            payload = extract_tool_line(reply)
            if payload is None:
                self.history.append({"role": "assistant", "content": reply})
                self._log_learning(user_text, reply)
                return reply

            self.history.append({"role": "assistant", "content": reply})
            result = execute_tool(payload, self.settings)
            self.history.append(
                {
                    "role": "user",
                    "content": f"Результат инструмента:\n{result}",
                }
            )

        final = chat_completion(
            self.settings,
            self.history,
            stream=False,
        )
        self.history.append({"role": "assistant", "content": final})
        self._log_learning(user_text, final)
        return final

    def _log_learning(self, user_text: str, assistant_text: str) -> None:
        sys_log = (
            self.history[0].get("content")
            if self.settings.learning_include_system
            else None
        )
        log_turn(
            self.settings,
            user_text,
            assistant_text,
            source="agent",
            system_content=sys_log,
        )
