import React, { useMemo, useState } from 'react';
import {
  Box,
  Button,
  Paper,
  Typography,
  Stack,
  Alert,
  Divider,
  Chip,
  CircularProgress,
} from '@mui/material';
import {
  CloudDone,
  ContentCopy,
  Science,
  Link as LinkIcon,
  Terminal,
  CheckCircle,
  Download,
  Replay,
  Inventory2,
} from '@mui/icons-material';
import api from '../../services/api';
import { submitMeIngest, quickDemoPayload } from '../../services/ingest.service';
import { resolveApiBase } from '../../utils/apiBase';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { useNotification } from '../../app/hooks/useNotification';


export const DeveloperHub: React.FC = () => {
  const { workspace, refreshWorkspace } = useWorkspace();
  const { showError, showSuccess } = useNotification();
  const [pinging, setPinging] = useState(false);
  const [selfTesting, setSelfTesting] = useState(false);
  const [replaying, setReplaying] = useState(false);
  const [sessionOk, setSessionOk] = useState<boolean | null>(null);

  const base = useMemo(() => resolveApiBase(), []);
  const ingestUrl = `${base.replace(/\/$/, '')}/api/waypoint/ingest`;
  const effectiveIngestKey = workspace.ingestApiKey ?? null;

  const curlSnippet = useMemo(() => {
    const k = effectiveIngestKey ?? 'YOUR_NX_API_KEY';
    return `curl -sS -X POST "${ingestUrl}" \\\n  -H "Content-Type: application/json" \\\n  -H "X-API-Key: ${k}" \\\n  -d '{"metrics":[{"name":"app.ready","value":1}],"logs":[]}'`;
  }, [ingestUrl, effectiveIngestKey]);

  const copyCurl = () => {
    void navigator.clipboard.writeText(curlSnippet);
    showSuccess('curl скопирован в буфер');
  };

  const pingSession = async () => {
    setPinging(true);
    setSessionOk(null);
    try {
      await api.get('/me/workspace');
      setSessionOk(true);
      showSuccess('Сессия API активна');
      await refreshWorkspace();
    } catch {
      setSessionOk(false);
      showError('Нет ответа от API — проверьте VITE_API_URL и CORS');
    } finally {
      setPinging(false);
    }
  };

  const runSelfTest = async () => {
    setSelfTesting(true);
    try {
      await api.post('/me/ingest/self-test');
      showSuccess('WaypointMetric: platform.selftest записана — откройте Ingest Lab');
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? String((e as { response?: { data?: { error?: string } } }).response?.data?.error)
          : '';
      showError(msg || 'Не удалось записать тестовую метрику');
    } finally {
      setSelfTesting(false);
    }
  };

  const downloadJson = (data: unknown, filename: string) => {
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    a.click();
    URL.revokeObjectURL(a.href);
  };

  const exportIngest = async () => {
    try {
      const r = await api.get('/me/ingest/export', { params: { limit: 500 } });
      downloadJson(r.data, `ingest-export-${Date.now()}.json`);
      showSuccess('Экспорт сохранён');
    } catch {
      showError('Экспорт недоступен');
    }
  };

  const replayIngest = async () => {
    setReplaying(true);
    try {
      const r = await api.post('/me/ingest/replay', { limit: 200 });
      const n = (r.data as { inserted?: number })?.inserted;
      showSuccess(`Replay: дублировано точек: ${n ?? '?'}`);
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? String((e as { response?: { data?: { error?: string } } }).response?.data?.error)
          : '';
      showError(msg || 'Replay не выполнен');
    } finally {
      setReplaying(false);
    }
  };

  const reproBundle = async () => {
    try {
      const r = await api.get('/me/repro-bundle');
      downloadJson(r.data, `repro-bundle-${Date.now()}.json`);
      showSuccess('repro-bundle сохранён — можно приложить к обращению');
    } catch {
      showError('Не удалось собрать repro-bundle');
    }
  };

  return (
    <Box sx={{ maxWidth: 960, mx: 'auto' }}>
      <Typography variant="h4" sx={{ fontWeight: 800, mb: 1 }}>
        Подключение к платформе
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3, lineHeight: 1.7 }}>
        Базовый URL этой консоли, ключ ingest и быстрые проверки — в одном месте. Соответствует сценарию на{' '}
        <strong>/platform</strong> и OpenAPI WaypointMetric.
      </Typography>

      <Stack spacing={2.5}>
        <Paper sx={{ p: 2.5, borderRadius: 3 }}>
          <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1.5 }}>
            <LinkIcon color="primary" />
            <Typography variant="h6" sx={{ fontWeight: 800 }}>
              База API (консоль)
            </Typography>
          </Stack>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
            На проде с nginx часто <code>/api</code>; локально — URL до порта API (например 8080).
          </Typography>
          <Box
            component="code"
            sx={{
              display: 'block',
              p: 1.5,
              borderRadius: 1,
              bgcolor: 'action.hover',
              fontFamily: 'monospace',
              fontSize: 13,
              wordBreak: 'break-all',
            }}
          >
            {base}
          </Box>
          <Stack direction="row" spacing={1} sx={{ mt: 2 }} flexWrap="wrap" useFlexGap>
            <Button
              variant="contained"
              onClick={() => void pingSession()}
              disabled={pinging}
              startIcon={pinging ? <CircularProgress size={18} color="inherit" /> : <CloudDone />}
            >
              Проверить сессию
            </Button>
            {sessionOk === true && <Chip icon={<CheckCircle />} label="OK" color="success" size="small" />}
            {sessionOk === false && <Chip label="Ошибка" color="error" size="small" />}
          </Stack>
        </Paper>

        <Paper sx={{ p: 2.5, borderRadius: 3 }}>
          <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1.5 }}>
            <Terminal color="primary" />
            <Typography variant="h6" sx={{ fontWeight: 800 }}>
              Ingest API
            </Typography>
          </Stack>
          <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1 }}>
            Endpoint
          </Typography>
          <Box component="code" sx={{ display: 'block', mb: 2, fontFamily: 'monospace', fontSize: 13, wordBreak: 'break-all' }}>
            POST {ingestUrl}
          </Box>
          {!effectiveIngestKey && (
            <Alert severity="info" sx={{ mb: 2 }}>
              Ключ появится после успешной загрузки workspace. Нажмите «Проверить сессию» или завершите онбординг.
            </Alert>
          )}
          {effectiveIngestKey && (
            <>
              <Typography variant="caption" color="text.secondary">
                X-API-Key (не пересылайте третьим лицам)
              </Typography>
              <Box
                component="code"
                sx={{
                  display: 'block',
                  p: 1.5,
                  mt: 0.5,
                  mb: 2,
                  borderRadius: 1,
                  bgcolor: 'action.hover',
                  fontFamily: 'monospace',
                  fontSize: 12,
                  wordBreak: 'break-all',
                }}
              >
                {effectiveIngestKey}
              </Box>
            </>
          )}
          <Divider sx={{ my: 2 }} />
          <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1 }}>
            Пример curl
          </Typography>
          <Box
            component="pre"
            sx={{
              m: 0,
              p: 2,
              borderRadius: 2,
              fontSize: 11,
              overflow: 'auto',
              fontFamily: 'monospace',
              bgcolor: 'action.hover',
              border: 1,
              borderColor: 'divider',
            }}
          >
            {curlSnippet}
          </Box>
          <Button startIcon={<ContentCopy />} onClick={copyCurl} sx={{ mt: 1.5 }}>
            Скопировать curl
          </Button>
        </Paper>

        <Paper sx={{ p: 2.5, borderRadius: 3 }}>
          <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1.5 }}>
            <Science color="primary" />
            <Typography variant="h6" sx={{ fontWeight: 800 }}>
              Проверка без curl
            </Typography>
          </Stack>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Сервер записывает метрику <code>platform.selftest</code> по вашему JWT (без X-API-Key в браузере).
          </Typography>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
            <Button
              variant="contained"
              color="secondary"
              onClick={() => void runSelfTest()}
              disabled={selfTesting}
              startIcon={selfTesting ? <CircularProgress size={18} color="inherit" /> : <Science />}
            >
              Записать тестовую метрику
            </Button>
            <Button
              variant="outlined"
              disabled={selfTesting}
              onClick={async () => {
                setSelfTesting(true);
                try {
                  const r = await submitMeIngest(quickDemoPayload);
                  showSuccess(`Демо ingest: ${r.ingested_metrics} метрик, ${r.ingested_logs} логов`);
                } catch (e: unknown) {
                  const msg =
                    e && typeof e === 'object' && 'response' in e
                      ? String((e as { response?: { data?: { error?: string } } }).response?.data?.error)
                      : '';
                  showError(msg || 'Не удалось записать демо');
                } finally {
                  setSelfTesting(false);
                }
              }}
            >
              Демо: метрики + лог
            </Button>
          </Stack>
        </Paper>

        <Paper sx={{ p: 2.5, borderRadius: 3 }}>
          <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1.5 }}>
            <Replay color="primary" />
            <Typography variant="h6" sx={{ fontWeight: 800 }}>
              Экспорт и replay
            </Typography>
          </Stack>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Снимок последних точек в JSON; replay дублирует их с новым временем и тегом <code>replay</code> — удобно
            проверить дашборды без внешних клиентов.
          </Typography>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5}>
            <Button variant="outlined" startIcon={<Download />} onClick={() => void exportIngest()}>
              Скачать export (ingest)
            </Button>
            <Button
              variant="outlined"
              color="warning"
              startIcon={replaying ? <CircularProgress size={18} /> : <Replay />}
              disabled={replaying}
              onClick={() => void replayIngest()}
            >
              Replay последних 200 точек
            </Button>
            <Button variant="outlined" startIcon={<Inventory2 />} onClick={() => void reproBundle()}>
              Скачать repro-bundle
            </Button>
          </Stack>
        </Paper>

        <Paper sx={{ p: 2.5, borderRadius: 3 }}>
          <Typography variant="h6" sx={{ fontWeight: 800, mb: 1 }}>
            Каналы артефактов (не только ядро Lynx)
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
            Публичный манифест: <code>GET {`${base}/artifacts/manifest/engine`}</code> — то же, что{' '}
            <code>/engine/manifest</code>. Другие slug настраиваются в БД (<code>platform_artifact_channel</code>).
          </Typography>
        </Paper>

        <Paper sx={{ p: 2.5, borderRadius: 3 }}>
          <Typography variant="h6" sx={{ fontWeight: 800, mb: 1 }}>
            Метрики с вашего Linux-сервера
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5, lineHeight: 1.7 }}>
            Скрипты в репозитории <code>scripts/waypoint_host_send_metrics.sh</code> и{' '}
            <code>scripts/waypoint_host_install_linux.sh</code>: load average, RAM, диск <code>/</code>, срез топ-процессов
            по CPU — уходят в ваш ingest каждые 2 минуты (systemd timer). Укажите полный URL ingest и API-ключ в{' '}
            <code>/etc/waypoint-metrics.env</code>.
          </Typography>
          <Typography variant="caption" color="text.secondary" component="div">
            Метрики: <code>host.load1</code>, <code>host.mem_used_percent</code>, <code>host.disk_root_used_percent</code>
            — смотрите в Ingest Lab и сводках.
          </Typography>
        </Paper>

        {(workspace.connectionUrl || workspace.agentApiKey) && (
          <Paper sx={{ p: 2.5, borderRadius: 3 }}>
            <Typography variant="h6" sx={{ fontWeight: 800, mb: 1 }}>
              Ваш агент (свой сервер)
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
              URL: {workspace.connectionUrl || '—'}
            </Typography>
            {workspace.agentApiKey && (
              <Typography variant="body2" component="div" sx={{ fontFamily: 'monospace', fontSize: 12, wordBreak: 'break-all' }}>
                X-Agent-Key: {workspace.agentApiKey}
              </Typography>
            )}
          </Paper>
        )}
      </Stack>
    </Box>
  );
};
