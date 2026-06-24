from __future__ import annotations

import time
from collections import defaultdict, deque

_buckets: dict[str, deque[float]] = defaultdict(deque)

def check_rate_limit(key: str, *, limit: int, window_sec: int) -> bool:
    """Return True if request is allowed."""
    if limit <= 0:
        return True
    now = time.monotonic()
    bucket = _buckets[key]
    while bucket and now - bucket[0] > window_sec:
        bucket.popleft()
    if len(bucket) >= limit:
        return False
    bucket.append(now)
    return True
