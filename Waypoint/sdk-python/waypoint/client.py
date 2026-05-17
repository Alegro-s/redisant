import requests
import time
import threading
import logging
from typing import Dict, List, Optional, Union
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

class WaypointMetric:
    """
    Клиент для отправки метрик и логов в Waypoint Metrics.
    
    Пример использования:
        client = WaypointClient(api_key="wpk_...", base_url="http://localhost:8080/api/waypoint")
        client.metric("users_online", 42, tags={"bot": "my_bot"})
        client.log("INFO", "Bot started")
    """
    def __init__(self, api_key: str, base_url: str = "http://localhost:8080/api/waypoint", flush_interval: int = 5):
        self.api_key = api_key
        self.base_url = base_url.rstrip('/')
        self.flush_interval = flush_interval
        self._metrics_buffer: List[Dict] = []
        self._logs_buffer: List[Dict] = []
        self._lock = threading.Lock()
        self._stop_event = threading.Event()
        self._thread = threading.Thread(target=self._flush_loop, daemon=True)
        self._thread.start()

    def _flush_loop(self):
        while not self._stop_event.wait(self.flush_interval):
            self.flush()

    def metric(self, name: str, value: Union[int, float], tags: Optional[Dict] = None):
        with self._lock:
            self._metrics_buffer.append({
                "name": name,
                "value": float(value),
                "tags": tags or {}
            })

    def log(self, level: str, message: str, tags: Optional[Dict] = None):
        with self._lock:
            self._logs_buffer.append({
                "level": level,
                "message": message,
                "tags": tags or {}
            })

    def flush(self):
        with self._lock:
            metrics = self._metrics_buffer.copy()
            logs = self._logs_buffer.copy()

        if not metrics and not logs:
            return

        payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "metrics": metrics,
            "logs": logs
        }
        try:
            resp = requests.post(
                f"{self.base_url}/ingest",
                headers={
                    "X-API-Key": self.api_key,
                    "Content-Type": "application/json"
                },
                json=payload,
                timeout=5
            )
            resp.raise_for_status()
            data = resp.json()
            with self._lock:
                del self._metrics_buffer[:len(metrics)]
                del self._logs_buffer[:len(logs)]
            logger.debug(
                "Sent %s metrics, %s logs",
                data.get('ingested_metrics', len(metrics)),
                data.get('ingested_logs', len(logs))
            )
        except Exception as e:
            logger.error(f"Failed to send metrics: {e}")

    def close(self):
        self._stop_event.set()
        self._thread.join()
        self.flush()