import type { CloudConfig } from './config';
import { sendIngest } from './cloud';

const QUEUE_KEY = 'waypoint_ingest_queue';

type Queued = { payload: unknown; ts: number };

function readQueue(): Queued[] {
  try {
    return JSON.parse(localStorage.getItem(QUEUE_KEY) || '[]') as Queued[];
  } catch {
    return [];
  }
}

function writeQueue(q: Queued[]) {
  localStorage.setItem(QUEUE_KEY, JSON.stringify(q));
}

export async function flushQueue(cfg: CloudConfig, online: boolean): Promise<number> {
  if (!online || !cfg.apiKey) return 0;
  const q = readQueue();
  if (!q.length) return 0;
  const rest: Queued[] = [];
  let sent = 0;
  for (const item of q) {
    try {
      await sendIngest(cfg, item.payload);
      sent++;
    } catch {
      rest.push(item);
    }
  }
  writeQueue(rest);
  return sent;
}

export function enqueue(payload: unknown) {
  const q = readQueue();
  q.push({ payload, ts: Date.now() });
  writeQueue(q.slice(-200));
}

export async function pushTelemetry(cfg: CloudConfig, online: boolean) {
  if (!cfg.syncTelemetry) return;
  const payload = {
    metrics: [
      { name: 'cpu_percent', value: Math.random() * 40 + 10, tags: { host: 'desktop', device: cfg.deviceId } },
      { name: 'desktop_online', value: online ? 1 : 0, tags: { host: cfg.deviceName } },
    ],
    logs: [{ level: 'info', message: 'waypoint desktop heartbeat' }],
  };
  if (!online || !cfg.apiKey) {
    enqueue(payload);
    return;
  }
  try {
    await sendIngest(cfg, payload);
  } catch {
    enqueue(payload);
  }
}
