
export type VkBotWorkerOpts = {
  
  waypointPublicBase: string;
};

export function buildVkBotWorkerPy(opts: VkBotWorkerOpts): string {
  const base = opts.waypointPublicBase.replace(/\/$/, '');
  const pullUrl = `${base}/api/waypoint/vk-bot/pull`;
  return `# -*- coding: utf-8 -*-
"""Waypoint → VK: исходящие запросы только от этого хоста (ваш API + api.vk.com).
Сгенерировано из консоли. Зависимости: только стандартная библиотека Python 3.9+.
"""
import json
import os
import sys
import urllib.error
import urllib.request
from urllib.parse import urlencode

WAYPOINT_PULL_URL = os.environ.get("WAYPOINT_VK_PULL_URL", "${pullUrl}")
WAYPOINT_API_KEY = os.environ.get("WAYPOINT_API_KEY", "")
VK_MODULE_TOKEN = os.environ.get("VK_MODULE_TOKEN", "")
VK_MODULE_SECRET = os.environ.get("VK_MODULE_SECRET", "")
VK_GROUP_TOKEN = os.environ.get("VK_GROUP_TOKEN", "")
VK_PEER_ID = int(os.environ.get("VK_PEER_ID", "0"))

def pull_digest():
    if not WAYPOINT_API_KEY or not VK_MODULE_SECRET or not VK_MODULE_TOKEN:
        print("Задайте WAYPOINT_API_KEY, VK_MODULE_TOKEN, VK_MODULE_SECRET", file=sys.stderr)
        sys.exit(1)
    req = urllib.request.Request(
        WAYPOINT_PULL_URL,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "X-API-Key": WAYPOINT_API_KEY,
            "X-VK-Module-Token": VK_MODULE_TOKEN,
            "X-VK-Module-Secret": VK_MODULE_SECRET,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        print(e.read().decode(errors="replace"), file=sys.stderr)
        raise
    if not data.get("ok"):
        raise RuntimeError("pull failed")
    return data.get("message") or ""

def vk_send(text: str):
    if not VK_GROUP_TOKEN or not VK_PEER_ID:
        print("Задайте VK_GROUP_TOKEN и VK_PEER_ID", file=sys.stderr)
        sys.exit(1)
    import random
    rid = random.randint(1, 2_147_000_000)
    form = urlencode(
        {
            "peer_id": str(VK_PEER_ID),
            "message": text[:4096],
            "access_token": VK_GROUP_TOKEN,
            "v": "5.131",
            "random_id": str(rid),
        }
    ).encode()
    req = urllib.request.Request(
        "https://api.vk.com/method/messages.send",
        data=form,
        method="POST",
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        body = resp.read().decode()
    if '"error"' in body:
        raise RuntimeError(body[:500])

def main():
    msg = pull_digest()
    vk_send(msg)
    print("OK")

if __name__ == "__main__":
    main()
`;
}
