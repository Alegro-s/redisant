import type { MetricsSummary, SimulateResult } from '../../waypoint/ingestTypes';

export interface MetricRow {
  name: string;
  value: number;
  tags: unknown;
  timestamp: string;
}

export const defaultSimJson = `{
  "metrics": [
    { "name": "cpu_percent", "value": 42.5, "tags": { "host": "test" } },
    { "name": "cpu_percent", "value": 55.0, "tags": { "host": "test" } },
    { "name": "", "value": 1.0 }
  ],
  "logs": [
    { "level": "info", "message": "deploy ok" },
    { "level": "error", "message": "disk full" },
    { "level": "warn", "message": "   " }
  ]
}`;

export const ingestDesktopSample = `{
  "metrics": [
    { "name": "cpu_percent", "value": 24.5, "tags": { "host": "desktop", "source": "waypoint-desktop" } },
    { "name": "docker_running", "value": 3, "tags": { "host": "desktop" } }
  ],
  "logs": [{ "level": "info", "message": "waypoint desktop heartbeat" }]
}`;

export const ingestSimSamples: Record<string, string> = {
  'Шаблон Desktop': ingestDesktopSample,
  'Валидный минимум': `{
  "metrics": [{ "name": "requests_per_s", "value": 120.5 }],
  "logs": [{ "level": "info", "message": "ok" }]
}`,
  'Нагрузочный батч': `{
  "metrics": [
    { "name": "latency_ms", "value": 12.3 },
    { "name": "latency_ms", "value": 48.1 },
    { "name": "queue_depth", "value": 4 }
  ],
  "logs": [{ "level": "warning", "message": "retry" }]
}`,
};

export function cleanIngestPayload(raw: unknown): unknown {
  if (!raw || typeof raw !== 'object') return raw;

  const out: Record<string, unknown> = { ...(raw as Record<string, unknown>) };

  const ms = Array.isArray(out.metrics) ? out.metrics : [];
  out.metrics = ms
    .filter((m: unknown) => m && typeof m === 'object')
    .map((m: Record<string, unknown>) => {
      const name = typeof m.name === 'string' ? m.name.trim() : '';
      const valueNum = typeof m.value === 'number' ? m.value : Number(m.value);
      return {
        ...m,
        name,
        value: valueNum,
      };
    })
    .filter(
      (m: Record<string, unknown>) =>
        typeof m.name === 'string' &&
        m.name.length > 0 &&
        typeof m.value === 'number' &&
        Number.isFinite(m.value),
    );

  if (Array.isArray(out.logs)) {
    out.logs = out.logs
      .filter((l: unknown) => l && typeof l === 'object')
      .map((l: Record<string, unknown>) => {
        const message = typeof l.message === 'string' ? l.message.trim() : '';
        return { ...l, message };
      })
      .filter((l: Record<string, unknown>) => typeof l.message === 'string' && l.message.length > 0);
  }

  return out;
}

export type { MetricsSummary, SimulateResult };
