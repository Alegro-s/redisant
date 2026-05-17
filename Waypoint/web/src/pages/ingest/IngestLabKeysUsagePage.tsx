import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  LinearProgress,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { ContentCopy, Delete as DeleteIcon, Edit as EditIcon } from '@mui/icons-material';
import { Link as RouterLink } from 'react-router-dom';
import { useNotification } from '../../app/hooks/useNotification';
import {
  createWaypointApiKey,
  deleteWaypointApiKey,
  fetchWaypointUsage,
  listWaypointApiKeys,
  patchWaypointApiKey,
  type WaypointApiKey,
  type WaypointUsageResponse,
} from '../../services/waypoint-console.service';

function extrapolateMonthly(count: number, windowDays: number): number {
  if (windowDays <= 0) return count;
  return Math.round((count * 30) / windowDays);
}

export const IngestLabKeysUsagePage: React.FC = () => {
  const { showError, showSuccess } = useNotification();
  const [keys, setKeys] = useState<WaypointApiKey[]>([]);
  const [usage, setUsage] = useState<WaypointUsageResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [newName, setNewName] = useState('');
  const [createdOnce, setCreatedOnce] = useState<string | null>(null);
  const [editOpen, setEditOpen] = useState(false);
  const [editId, setEditId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');

  const loadAll = useCallback(async () => {
    setLoading(true);
    try {
      const [k, u] = await Promise.all([listWaypointApiKeys(), fetchWaypointUsage()]);
      setKeys(k);
      setUsage(u);
    } catch {
      showError('Не удалось загрузить ключи или отчёт использования');
    } finally {
      setLoading(false);
    }
  }, [showError]);

  useEffect(() => {
    void loadAll();
  }, [loadAll]);

  const metricsPace = useMemo(() => {
    if (!usage) return { extrap: 0, cap: 1 };
    const extrap = extrapolateMonthly(usage.totals.metrics, usage.window_days);
    const cap = Math.max(1, usage.quotas.metrics_per_month_soft_cap);
    return { extrap, cap };
  }, [usage]);

  const logsPace = useMemo(() => {
    if (!usage) return { extrap: 0, cap: 1 };
    const extrap = extrapolateMonthly(usage.totals.logs, usage.window_days);
    const cap = Math.max(1, usage.quotas.log_lines_per_month_soft_cap);
    return { extrap, cap };
  }, [usage]);

  const onCreate = async () => {
    const n = newName.trim();
    if (!n) return;
    setLoading(true);
    try {
      const r = await createWaypointApiKey(n);
      setCreatedOnce(r.key);
      setNewName('');
      showSuccess('Ключ создан — скопируйте сейчас, полное значение больше не показывается в списке.');
      await loadAll();
    } catch {
      showError('Не удалось создать ключ');
    } finally {
      setLoading(false);
    }
  };

  const onDelete = async (id: string) => {
    if (!window.confirm('Удалить ключ? Ingest с этим ключом перестанет проходить.')) return;
    setLoading(true);
    try {
      await deleteWaypointApiKey(id);
      showSuccess('Ключ удалён');
      await loadAll();
    } catch {
      showError('Удаление не удалось');
    } finally {
      setLoading(false);
    }
  };

  const openEdit = (k: WaypointApiKey) => {
    setEditId(k.id);
    setEditName(k.name);
    setEditOpen(true);
  };

  const saveEdit = async () => {
    if (!editId) return;
    const n = editName.trim();
    if (!n) return;
    setLoading(true);
    try {
      await patchWaypointApiKey(editId, n);
      showSuccess('Имя ключа обновлено');
      setEditOpen(false);
      await loadAll();
    } catch {
      showError('Не удалось сохранить');
    } finally {
      setLoading(false);
    }
  };

  const byKeyMap = useMemo(() => {
    const m = new Map<string, { metrics: number; logs: number; dev_events: number }>();
    usage?.by_api_key.forEach((r) =>
      m.set(r.id, { metrics: r.metrics_30d, logs: r.logs_30d, dev_events: r.dev_events_30d ?? 0 }),
    );
    return m;
  }, [usage]);

  return (
    <Box>
      <Typography variant="subtitle1" gutterBottom sx={{ fontWeight: 600 }}>
        Коммерческая консоль: ключи ingest и расход
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Ключи с префиксом <code>wpk_</code> для <code>POST /api/waypoint/ingest</code> и интеграций. Квоты ниже — ориентир для
        планов и self-hosted (настраиваются через{' '}
        <code>WAYPOINT_QUOTA_METRICS_MONTH</code>, <code>WAYPOINT_QUOTA_LOG_LINES_MONTH</code>,{' '}
        <code>WAYPOINT_INGEST_RPM_PER_KEY</code>). Жёсткий rate limit ingest при включённом Redis — см. лимит в ответе usage и
        код <code>waypoint/ingest.rs</code>. Связка с оплатой: раздел{' '}
        <RouterLink to="/dashboard/billing">Биллинг</RouterLink>.
      </Typography>

      {usage && (
        <Paper sx={{ p: 2, mb: 2 }}>
          <Typography variant="subtitle2" gutterBottom>
            Использование за {usage.window_days} дн. (экстраполяция на ~30 дн. vs soft cap)
          </Typography>
          <Stack spacing={1.5}>
            <Box>
              <Typography variant="caption" color="text.secondary">
                Метрики: {usage.totals.metrics.toLocaleString()} точек за период → ~{metricsPace.extrap.toLocaleString()}/мес
                (cap {metricsPace.cap.toLocaleString()})
              </Typography>
              <LinearProgress
                variant="determinate"
                value={Math.min(100, (metricsPace.extrap / metricsPace.cap) * 100)}
                sx={{ mt: 0.5, height: 8, borderRadius: 1 }}
              />
            </Box>
            <Box>
              <Typography variant="caption" color="text.secondary">
                Логи: {usage.totals.logs.toLocaleString()} строк → ~{logsPace.extrap.toLocaleString()}/мес (cap{' '}
                {logsPace.cap.toLocaleString()})
              </Typography>
              <LinearProgress
                variant="determinate"
                color="secondary"
                value={Math.min(100, (logsPace.extrap / logsPace.cap) * 100)}
                sx={{ mt: 0.5, height: 8, borderRadius: 1 }}
              />
            </Box>
            <Typography variant="caption" color="text.secondary" display="block">
              События (performance/SMM/storage…): {usage.totals.dev_events?.toLocaleString() ?? '0'} за период
            </Typography>
            <Typography variant="caption" color="text.secondary">
              RPM на ключ (ориентир): {usage.quotas.ingest_rpm_per_api_key_cap.toLocaleString()}
            </Typography>
          </Stack>
        </Paper>
      )}

      {createdOnce && (
        <Alert
          severity="warning"
          sx={{ mb: 2 }}
          action={
            <Button
              size="small"
              startIcon={<ContentCopy />}
              onClick={async () => {
                await navigator.clipboard.writeText(createdOnce);
                showSuccess('Скопировано');
              }}
            >
              Копировать ключ
            </Button>
          }
        >
          <Typography variant="body2" sx={{ wordBreak: 'break-all', fontFamily: 'monospace' }}>
            {createdOnce}
          </Typography>
        </Alert>
      )}

      <Paper sx={{ p: 2, mb: 2 }}>
        <Typography variant="subtitle2" gutterBottom>
          Новый API-ключ
        </Typography>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'center' }}>
          <TextField
            size="small"
            fullWidth
            label="Имя (окружение, сервис)"
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
          />
          <Button variant="contained" onClick={() => void onCreate()} disabled={loading || !newName.trim()}>
            Выпустить ключ
          </Button>
        </Stack>
      </Paper>

      <Paper sx={{ mb: 2, overflow: 'auto' }}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Имя</TableCell>
              <TableCell>Ключ (маска)</TableCell>
              <TableCell align="right">Метрики ({usage?.window_days ?? '—'}д)</TableCell>
              <TableCell align="right">Логи</TableCell>
              <TableCell align="right">События</TableCell>
              <TableCell>Последний ingest</TableCell>
              <TableCell align="right">Действия</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {keys.map((k) => {
              const u = byKeyMap.get(k.id);
              return (
                <TableRow key={k.id}>
                  <TableCell>{k.name}</TableCell>
                  <TableCell sx={{ fontFamily: 'monospace' }}>{k.key_masked}</TableCell>
                  <TableCell align="right">{(u?.metrics ?? 0).toLocaleString()}</TableCell>
                  <TableCell align="right">{(u?.logs ?? 0).toLocaleString()}</TableCell>
                  <TableCell align="right">{(u?.dev_events ?? 0).toLocaleString()}</TableCell>
                  <TableCell>{k.last_used ? new Date(k.last_used).toLocaleString() : '—'}</TableCell>
                  <TableCell align="right">
                    <Button size="small" startIcon={<EditIcon />} onClick={() => openEdit(k)}>
                      Имя
                    </Button>
                    <Button size="small" color="error" startIcon={<DeleteIcon />} onClick={() => void onDelete(k.id)}>
                      Удалить
                    </Button>
                  </TableCell>
                </TableRow>
              );
            })}
            {keys.length === 0 && !loading && (
              <TableRow>
                <TableCell colSpan={7}>
                  Нет ключей — создайте первый для отправки метрик с продакшена.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </Paper>

      {usage && usage.by_day.length > 0 && (
        <Paper sx={{ p: 2 }}>
          <Typography variant="subtitle2" gutterBottom>
            Суточная нагрузка (метрики / логи)
          </Typography>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>День (UTC)</TableCell>
                <TableCell align="right">Метрики</TableCell>
                <TableCell align="right">Логи</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {usage.by_day
                .slice()
                .reverse()
                .slice(0, 14)
                .map((d) => (
                  <TableRow key={d.day}>
                    <TableCell>{d.day}</TableCell>
                    <TableCell align="right">{d.metrics.toLocaleString()}</TableCell>
                    <TableCell align="right">{d.logs.toLocaleString()}</TableCell>
                  </TableRow>
                ))}
            </TableBody>
          </Table>
          <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 1 }}>
            Показаны последние 14 дней из окна {usage.window_days} дн.
          </Typography>
        </Paper>
      )}

      <Dialog open={editOpen} onClose={() => setEditOpen(false)} fullWidth maxWidth="sm">
        <DialogTitle>Переименовать ключ</DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            fullWidth
            label="Имя"
            value={editName}
            onChange={(e) => setEditName(e.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditOpen(false)}>Отмена</Button>
          <Button variant="contained" onClick={() => void saveEdit()} disabled={!editName.trim() || loading}>
            Сохранить
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};
