"""
Правила зеркалят server/src/waypoint/ingest_payload.rs.
При изменении логики на сервере обновите и этот файл и cargo test.
"""

import math
import unittest
from typing import Union

MAX_METRIC_NAME_LEN = 256
MAX_LOG_MESSAGE_LEN = 8192


def metric_acceptable(name: str, value: Union[int, float]) -> bool:
    n = name.strip()
    if not n or len(n) > MAX_METRIC_NAME_LEN:
        return False
    v = float(value)
    return math.isfinite(v)


def log_acceptable(_level: str, message: str) -> bool:
    msg = message.strip()
    if not msg:
        return False
    return len(message) <= MAX_LOG_MESSAGE_LEN


def log_triggers_alert(level: str) -> bool:
    return level.lower() in ("error", "critical", "fatal")


class TestIngestRules(unittest.TestCase):
    def test_metric(self):
        self.assertTrue(metric_acceptable("cpu", 1.0))
        self.assertTrue(metric_acceptable("cpu", 1))
        self.assertFalse(metric_acceptable("", 1.0))
        self.assertFalse(metric_acceptable("cpu", float("nan")))
        self.assertFalse(metric_acceptable("cpu", float("inf")))
        self.assertTrue(metric_acceptable("a" * 256, 0.0))
        self.assertFalse(metric_acceptable("a" * 257, 0.0))

    def test_log(self):
        self.assertTrue(log_acceptable("info", "ok"))
        self.assertFalse(log_acceptable("warn", ""))
        self.assertFalse(log_acceptable("warn", "   "))
        self.assertTrue(log_triggers_alert("ERROR"))
        self.assertFalse(log_triggers_alert("info"))


if __name__ == "__main__":
    unittest.main()
