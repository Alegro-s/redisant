import React, { useCallback, useEffect, useState } from 'react';
import { Link as RouterLink } from 'react-router-dom';
import {
  Box,
  Typography,
  Paper,
  Tabs,
  Tab,
  Button,
  TextField,
  Alert,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Chip,
  Stack,
  Divider,
} from '@mui/material';
import api from '../../services/api';
import type { MetricsSummary, SimulateResult } from '../../waypoint/ingestTypes';

interface MetricRow {
  name: string;
  value: number;
  tags: unknown;
  timestamp: string;
}

const defaultSimJson = `{
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

const samples: Record<string, string> = {
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

export const IngestLab: React.FC = () => {
  const [tab, setTab] = useState(0);
  const [metrics, setMetrics] = useState<MetricRow[]>([]);
  const [summary, setSummary] = useState<MetricsSummary | null>(null);
  const [simJson, setSimJson] = useState(defaultSimJson);
  const [simResult, setSimResult] = useState<SimulateResult | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const cleanIngestPayload = (raw: any) => {
    if (!raw || typeof raw !== 'object') return raw;

    const out: any = { ...raw };

    const ms = Array.isArray(out.metrics) ? out.metrics : [];
    out.metrics = ms
      .filter((m: any) => m && typeof m === 'object')
      .map((m: any) => {
        const name = typeof m.name === 'string' ? m.name.trim() : '';
        const valueNum = typeof m.value === 'number' ? m.value : Number(m.value);
        return {
          ...m,
          name,
          value: valueNum,
        };
      })
      .filter(
        (m: any) =>
          typeof m.name === 'string' &&
          m.name.length > 0 &&
          typeof m.value === 'number' &&
          Number.isFinite(m.value),
      );

    if (Array.isArray(out.logs)) {
      out.logs = out.logs
        .filter((l: any) => l && typeof l === 'object')
        .map((l: any) => {
          const message = typeof l.message === 'string' ? l.message.trim() : '';
          return { ...l, message };
        })
        .filter((l: any) => typeof l.message === 'string' && l.message.length > 0);
    }

    return out;
  };

  const loadMetrics = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const { data } = await api.get<MetricRow[]>('/me/metrics');
      setMetrics(data);
    } catch (e: unknown) {
      const err = e as { response?: { data?: { error?: string } } };
      setError(err.response?.data?.error || 'Нет доступа к /me/metrics (нужен JWT пользователя)');
    } finally {
      setLoading(false);
    }
  }, []);

  const loadSummary = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const { data } = await api.get<MetricsSummary>('/me/metrics/summary');
      setSummary(data);
    } catch (e: unknown) {
      const err = e as { response?: { data?: { error?: string } } };
      setError(err.response?.data?.error || 'Нет доступа к /me/metrics/summary');
      setSummary(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (tab === 0) loadMetrics();
    if (tab === 1) loadSummary();
  }, [tab, loadMetrics, loadSummary]);

  const runSimulate = async () => {
    setError('');
    setSimResult(null);
    try {
      const parsed = JSON.parse(simJson);
      const body = cleanIngestPayload(parsed);
      const { data } = await api.post<SimulateResult>('/me/ingest/simulate', body);
      setSimResult(data);
    } catch (e: unknown) {
      const err = e as { message?: string; response?: { data?: { error?: string } } };
      setError(err.response?.data?.error || err.message || 'Ошибка JSON или сети');
    }
  };

  return (
    <Box p={2}>
      <Typography variant="h5" gutterBottom>
        Ingest Lab
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        <strong>WaypointMetric</strong> — ingest и телеметрия, не редактор движка. Поток:{' '}
        <strong>JSON → симуляция (валидация + агрегаты)</strong> → реальный <code>POST /api/waypoint/ingest</code> с{' '}
        <code>X-API-Key</code> → те же данные в <RouterLink to="/dashboard">дашборде</RouterLink> (сводка и график). Правила
        пропуска точек совпадают с сервером.
      </Typography>

      <Paper sx={{ mb: 2 }}>
        <Tabs value={tab} onChange={(_, v) => setTab(v)}>
          <Tab label="Таблица метрик" />
          <Tab label="Сводка → дашборд" />
          <Tab label="Симуляция и анализ" />
        </Tabs>
      </Paper>

      {error && (
        <Alert severity="warning" sx={{ mb: 2 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}

      {tab === 0 && (
        <Paper>
          <Box p={2} display="flex" justifyContent="space-between" alignItems="center">
            <Typography variant="subtitle1">GET /me/metrics (последние точки)</Typography>
            <Button variant="outlined" onClick={loadMetrics} disabled={loading}>
              Обновить
            </Button>
          </Box>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Время</TableCell>
                <TableCell>Имя</TableCell>
                <TableCell align="right">Значение</TableCell>
                <TableCell>Теги</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {metrics.slice(0, 100).map((m, i) => (
                <TableRow key={`${m.timestamp}-${i}`}>
                  <TableCell>{m.timestamp}</TableCell>
                  <TableCell>{m.name}</TableCell>
                  <TableCell align="right">{m.value}</TableCell>
                  <TableCell>
                    <code>{JSON.stringify(m.tags)}</code>
                  </TableCell>
                </TableRow>
              ))}
              {metrics.length === 0 && !loading && (
                <TableRow>
                  <TableCell colSpan={4}>
                    Пока нет данных. Отправьте метрики на ingest или используйте вкладку симуляции, чтобы проверить формат.
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </Paper>
      )}

      {tab === 1 && (
        <Paper sx={{ p: 2 }}>
          <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
            <Typography variant="subtitle1">GET /me/metrics/summary (как на дашборде)</Typography>
            <Button variant="outlined" onClick={loadSummary} disabled={loading}>
              Обновить
            </Button>
          </Box>
          {summary && (
            <Stack spacing={2}>
              <Stack direction="row" gap={1} flexWrap="wrap">
                <Chip label={`Всего точек: ${summary.total_points}`} />
                <Chip label={`Имён: ${summary.unique_metric_names}`} />
                <Chip label={`24ч: ${summary.points_last_24h}`} color="primary" variant="outlined" />
                <Chip
                  label={`Алерт-логи 24ч: ${summary.alert_logs_last_24h}`}
                  color={summary.alert_logs_last_24h > 0 ? 'warning' : 'default'}
                />
              </Stack>
              <Typography variant="body2" color="text.secondary">
                latest_by_name — последнее значение по каждому имени (до 12 рядов), те же данные строят столбчатую диаграмму на главной.
              </Typography>
              <Table size="small">
                <TableHead>
                  <TableRow>
                    <TableCell>Имя</TableCell>
                    <TableCell align="right">Значение</TableCell>
                    <TableCell>Время</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {summary.latest_by_name.map((r) => (
                    <TableRow key={r.name}>
                      <TableCell>{r.name}</TableCell>
                      <TableCell align="right">{r.value}</TableCell>
                      <TableCell>{r.timestamp}</TableCell>
                    </TableRow>
                  ))}
                  {summary.latest_by_name.length === 0 && (
                    <TableRow>
                      <TableCell colSpan={3}>Нет серий</TableCell>
                    </TableRow>
                  )}
                </TableBody>
              </Table>
            </Stack>
          )}
        </Paper>
      )}

      {tab === 2 && (
        <Paper sx={{ p: 2 }}>
          <Typography variant="subtitle2" gutterBottom>
            POST /me/ingest/simulate — без записи в БД; те же проверки, что при ingest
          </Typography>
          <Stack direction="row" gap={1} flexWrap="wrap" sx={{ mb: 2 }}>
            {Object.entries(samples).map(([label, json]) => (
              <Button key={label} size="small" variant="outlined" onClick={() => setSimJson(json)}>
                {label}
              </Button>
            ))}
            <Button size="small" onClick={() => setSimJson(defaultSimJson)}>
              Пример с ошибками
            </Button>
          </Stack>
          <TextField
            fullWidth
            multiline
            minRows={12}
            value={simJson}
            onChange={(e) => setSimJson(e.target.value)}
            sx={{ mb: 2, '& textarea': { fontFamily: 'monospace', fontSize: 13 } }}
          />
          <Button variant="contained" onClick={runSimulate}>
            Запустить симуляцию
          </Button>

          {simResult && (
            <Box mt={3}>
              <Divider sx={{ mb: 2 }} />
              <Typography variant="subtitle1" gutterBottom>
                Результат
              </Typography>
              <Stack direction="row" gap={1} flexWrap="wrap" sx={{ mb: 2 }}>
                <Chip
                  label={simResult.validation?.ok ? 'Валидация: OK' : 'Есть проблемы'}
                  color={simResult.validation?.ok ? 'success' : 'error'}
                  size="small"
                />
                <Chip
                  label={`Примутся метрик: ${simResult.would_ingest?.metrics ?? 0} / пропуск: ${simResult.would_ingest?.skipped_metrics ?? 0}`}
                  size="small"
                />
                <Chip
                  label={`Логи: ${simResult.would_ingest?.logs ?? 0} / пропуск: ${simResult.would_ingest?.skipped_logs ?? 0}`}
                  size="small"
                />
                <Chip
                  label={`Алерт-логи: ${simResult.analysis?.logs_that_would_trigger_alert ?? 0}`}
                  color={(simResult.analysis?.logs_that_would_trigger_alert ?? 0) > 0 ? 'warning' : 'default'}
                  size="small"
                />
              </Stack>
              {simResult.validation?.warnings?.length ? (
                <Alert severity="info" sx={{ mb: 2 }}>
                  {simResult.validation.warnings.join(' · ')}
                </Alert>
              ) : null}
              {simResult.validation?.issues?.length ? (
                <Alert severity="error" sx={{ mb: 2 }}>
                  <Typography variant="subtitle2">Issues</Typography>
                  <ul style={{ margin: '8px 0 0', paddingLeft: 18 }}>
                    {simResult.validation.issues.map((iss, i) => (
                      <li key={i}>
                        <code>{iss.code}</code> — {iss.message}
                        {iss.index != null ? ` (#${iss.index})` : ''}
                      </li>
                    ))}
                  </ul>
                </Alert>
              ) : null}
              {simResult.analysis?.series_summary?.length ? (
                <>
                  <Typography variant="subtitle2" sx={{ mt: 2, mb: 1 }}>
                    Агрегаты по имени (как после ingest нескольких точек)
                  </Typography>
                  <Table size="small" sx={{ mb: 2 }}>
                    <TableHead>
                      <TableRow>
                        <TableCell>Имя</TableCell>
                        <TableCell align="right">N</TableCell>
                        <TableCell align="right">min</TableCell>
                        <TableCell align="right">max</TableCell>
                        <TableCell align="right">avg</TableCell>
                        <TableCell align="right">last</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {simResult.analysis.series_summary.map((s) => (
                        <TableRow key={s.name}>
                          <TableCell>{s.name}</TableCell>
                          <TableCell align="right">{s.count}</TableCell>
                          <TableCell align="right">{s.min.toFixed(3)}</TableCell>
                          <TableCell align="right">{s.max.toFixed(3)}</TableCell>
                          <TableCell align="right">{s.avg.toFixed(3)}</TableCell>
                          <TableCell align="right">{s.last.toFixed(3)}</TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </>
              ) : null}
              {simResult.analysis?.log_level_counts &&
                Object.keys(simResult.analysis.log_level_counts).length > 0 && (
                  <Typography variant="body2" sx={{ mb: 1 }}>
                    Уровни логов:{' '}
                    {Object.entries(simResult.analysis.log_level_counts)
                      .map(([k, v]) => `${k}: ${v}`)
                      .join(', ')}
                  </Typography>
                )}
              <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1 }}>
                Админский preview того же отчёта: POST /api/waypoint/ai/analyze с телом{' '}
                <code>{`{ "target_type":"x","target":"y","ingest": { ... } }`}</code>
              </Typography>
              <Typography variant="subtitle2" gutterBottom>
                Сырой JSON
              </Typography>
              <Box
                component="pre"
                sx={{
                  overflow: 'auto',
                  bgcolor: 'grey.900',
                  color: 'grey.100',
                  p: 2,
                  borderRadius: 1,
                  fontSize: 12,
                  maxHeight: 360,
                }}
              >
                {JSON.stringify(simResult, null, 2)}
              </Box>
            </Box>
          )}
        </Paper>
      )}
    </Box>
  );
};
