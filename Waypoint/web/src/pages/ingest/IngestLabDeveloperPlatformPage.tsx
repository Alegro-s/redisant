import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  FormControl,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { Refresh as RefreshIcon } from '@mui/icons-material';
import { useNotification } from '../../app/hooks/useNotification';
import {
  WAYPOINT_DEV_EVENT_CHANNELS,
  createWaypointNetworkDrive,
  deleteWaypointNetworkDrive,
  listWaypointDeveloperEvents,
  listWaypointNetworkDrives,
  type WaypointDevEvent,
  type WaypointNetworkDrive,
} from '../../services/waypoint-developer.service';

const CHANNEL_HELP: Record<string, string> = {
  performance: 'Performance marketing: конверсии, клики, CPA/ROAS, воронки оплат',
  brandformance: 'Brandformance: охваты, узнаваемость, брендовые события',
  smm: 'SMM: посты, вовлечённость, кросс-постинг в соцсети',
  reputation: 'Репутация / SERM: отзывы, сентимент, устранение негатива',
  analytics: 'Аналитика: CJM, BI-события, скрининг UX',
  web_dev: 'Web / релизы: деплой, версии, health сайта',
  design: 'Дизайн и продакшн: варианты креативов, A/B визуала',
  storage: 'Хранилища: сетевые диски, синхронизация с S3/WebDAV (см. реестр ниже)',
};

export const IngestLabDeveloperPlatformPage: React.FC = () => {
  const { showError, showSuccess } = useNotification();
  const [events, setEvents] = useState<WaypointDevEvent[]>([]);
  const [drives, setDrives] = useState<WaypointNetworkDrive[]>([]);
  const [loading, setLoading] = useState(false);
  const [channelFilter, setChannelFilter] = useState<string>('');

  const [ndName, setNdName] = useState('');
  const [ndProto, setNdProto] = useState('timeweb_s3');
  const [ndEndpoint, setNdEndpoint] = useState('');
  const [ndPrefix, setNdPrefix] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [ev, dr] = await Promise.all([
        listWaypointDeveloperEvents({
          limit: 150,
          channel: channelFilter || undefined,
        }),
        listWaypointNetworkDrives(),
      ]);
      setEvents(ev);
      setDrives(dr);
    } catch {
      showError('Не удалось загрузить события или сетевые диски');
    } finally {
      setLoading(false);
    }
  }, [channelFilter, showError]);

  useEffect(() => {
    void load();
  }, [load]);

  const addDrive = async () => {
    const n = ndName.trim();
    const ep = ndEndpoint.trim();
    if (!n || !ep) return;
    setLoading(true);
    try {
      await createWaypointNetworkDrive({
        name: n,
        protocol: ndProto,
        endpoint_uri: ep,
        path_prefix: ndPrefix.trim(),
        meta: { note: 'Реестр подключения; mount/sync на стороне приложения или воркера.' },
      });
      showSuccess('Запись добавлена');
      setNdName('');
      setNdEndpoint('');
      setNdPrefix('');
      await load();
    } catch {
      showError('Не удалось создать запись');
    } finally {
      setLoading(false);
    }
  };

  const removeDrive = async (id: string) => {
    if (!window.confirm('Удалить запись реестра?')) return;
    setLoading(true);
    try {
      await deleteWaypointNetworkDrive(id);
      showSuccess('Удалено');
      await load();
    } catch {
      showError('Удаление не удалось');
    } finally {
      setLoading(false);
    }
  };

  const exampleJson = `{
  "metrics": [{ "name": "checkout_latency_ms", "value": 42 }],
  "logs": [{ "level": "info", "message": "deploy ok" }],
  "events": [
    {
      "channel": "performance",
      "event": "purchase",
      "value": 1,
      "properties": { "campaign": "spring", "amount_rub": 990 }
    },
    {
      "channel": "storage",
      "event": "network_drive_synced_bytes",
      "value": 1048576,
      "properties": { "drive_label": "tw-backup-1", "protocol": "s3" }
    }
  ]
}`;

  return (
    <Box>
      <Typography variant="subtitle1" gutterBottom sx={{ fontWeight: 600 }}>
        Платформа разработчика: маркетинговые каналы + реестр сетевых дисков
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Поле <code>events</code> в <code>POST /api/waypoint/ingest</code> — структурные события по каналам (в духе performance /
        SMM / reputation / analytics / web_dev / design / storage). Таблица <code>waypoint_dev_events</code>. Реестр{' '}
        <code>network-drives</code> хранит endpoint и протокол (S3, WebDAV, NFS, SMB, ftp, timeweb_s3) для ваших скриптов
        синхронизации — аналог «сетевого диска» облака без монтирования на сервер API.
      </Typography>

      <Paper sx={{ p: 2, mb: 2 }}>
        <Typography variant="subtitle2" gutterBottom>
          Каналы и смысл (ingest → BI / AI)
        </Typography>
        <Stack spacing={1}>
          {WAYPOINT_DEV_EVENT_CHANNELS.map((c) => (
            <Typography key={c} variant="body2">
              <strong>{c}</strong> — {CHANNEL_HELP[c] ?? '—'}
            </Typography>
          ))}
        </Stack>
      </Paper>

      <Alert severity="info" sx={{ mb: 2 }}>
        <Typography variant="body2" component="pre" sx={{ whiteSpace: 'pre-wrap', fontFamily: 'monospace', m: 0 }}>
          {exampleJson}
        </Typography>
      </Alert>

      <Paper sx={{ p: 2, mb: 2 }}>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }} sx={{ mb: 2 }}>
          <FormControl size="small" sx={{ minWidth: 200 }}>
            <InputLabel>Канал (фильтр)</InputLabel>
            <Select
              label="Канал (фильтр)"
              value={channelFilter}
              onChange={(e) => setChannelFilter(e.target.value as string)}
            >
              <MenuItem value="">Все</MenuItem>
              {WAYPOINT_DEV_EVENT_CHANNELS.map((c) => (
                <MenuItem key={c} value={c}>
                  {c}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <Button startIcon={<RefreshIcon />} onClick={() => void load()} disabled={loading} variant="outlined">
            Обновить события
          </Button>
        </Stack>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Время (UTC)</TableCell>
              <TableCell>Канал</TableCell>
              <TableCell>Событие</TableCell>
              <TableCell align="right">Value</TableCell>
              <TableCell>Properties</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {events.map((e) => (
              <TableRow key={e.id}>
                <TableCell>{new Date(e.timestamp).toLocaleString()}</TableCell>
                <TableCell>{e.channel}</TableCell>
                <TableCell>{e.event_name}</TableCell>
                <TableCell align="right">{e.value ?? '—'}</TableCell>
                <TableCell sx={{ maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {e.properties ? JSON.stringify(e.properties) : '—'}
                </TableCell>
              </TableRow>
            ))}
            {events.length === 0 && !loading && (
              <TableRow>
                <TableCell colSpan={5}>
                  Пока нет событий — отправьте батч с <code>events</code> через ingest.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </Paper>

      <Paper sx={{ p: 2 }}>
        <Typography variant="subtitle2" gutterBottom>
          Реестр сетевых дисков / object storage
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Секреты (ключи) не храните в <code>meta</code> в открытом виде в продакшене — используйте переменные окружения у
          воркера; здесь только URI и подпись протокола.
        </Typography>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} sx={{ mb: 2 }} flexWrap="wrap">
          <TextField
            size="small"
            label="Имя"
            value={ndName}
            onChange={(e) => setNdName(e.target.value)}
            sx={{ minWidth: 160 }}
          />
          <FormControl size="small" sx={{ minWidth: 140 }}>
            <InputLabel>Протокол</InputLabel>
            <Select label="Протокол" value={ndProto} onChange={(e) => setNdProto(e.target.value as string)}>
              {['s3', 'timeweb_s3', 'webdav', 'nfs', 'smb', 'ftp', 'custom'].map((p) => (
                <MenuItem key={p} value={p}>
                  {p}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <TextField
            size="small"
            label="Endpoint URI"
            value={ndEndpoint}
            onChange={(e) => setNdEndpoint(e.target.value)}
            sx={{ flex: 1, minWidth: 220 }}
            placeholder="https://s3.ru-7.storage.selcloud.ru"
          />
          <TextField
            size="small"
            label="path_prefix"
            value={ndPrefix}
            onChange={(e) => setNdPrefix(e.target.value)}
            sx={{ minWidth: 120 }}
          />
          <Button variant="contained" onClick={() => void addDrive()} disabled={loading}>
            Добавить
          </Button>
        </Stack>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Имя</TableCell>
              <TableCell>Протокол</TableCell>
              <TableCell>Endpoint</TableCell>
              <TableCell>prefix</TableCell>
              <TableCell align="right">Действия</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {drives.map((d) => (
              <TableRow key={d.id}>
                <TableCell>{d.name}</TableCell>
                <TableCell>{d.protocol}</TableCell>
                <TableCell sx={{ fontFamily: 'monospace', maxWidth: 360 }}>{d.endpoint_uri}</TableCell>
                <TableCell>{d.path_prefix || '—'}</TableCell>
                <TableCell align="right">
                  <Button size="small" color="error" onClick={() => void removeDrive(d.id)}>
                    Удалить
                  </Button>
                </TableCell>
              </TableRow>
            ))}
            {drives.length === 0 && !loading && (
              <TableRow>
                <TableCell colSpan={5}>Нет записей — добавьте S3/WebDAV endpoint для команд деплоя или бэкапа.</TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </Paper>
    </Box>
  );
};
