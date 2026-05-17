import api from './api';

export type IngestWriteResult = {
  status: string;
  ingested_metrics: number;
  ingested_logs: number;
  ingested_dev_events?: number;
  skipped_metrics?: number;
  skipped_logs?: number;
  skipped_dev_events?: number;
};

export type IngestLogRow = {
  level: string;
  message: string;
  tags: unknown;
  timestamp: string;
};

/** Реальная запись в БД Metric (сессия, без X-API-Key в запросе). */
export async function submitMeIngest(body: unknown): Promise<IngestWriteResult> {
  const { data } = await api.post<IngestWriteResult>('/me/ingest', body);
  return data;
}

export async function fetchMyIngestLogs(): Promise<IngestLogRow[]> {
  const { data } = await api.get<IngestLogRow[]>('/me/logs');
  return data;
}

export const quickDemoPayload = {
  metrics: [
    { name: 'app.ready', value: 1, tags: { source: 'metric_console' } },
    { name: 'requests_per_s', value: 42.5, tags: { env: 'demo' } },
  ],
  logs: [{ level: 'info', message: 'Waypoint Metric: тестовая запись из браузера' }],
  events: [],
};
