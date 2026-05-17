import React, { useEffect, useMemo, useState } from 'react';
import {
  Box,
  Button,
  Chip,
  FormGroup,
  FormControlLabel,
  Checkbox,
  Paper,
  Stack,
  TextField,
  Typography,
  Divider,
  Alert,
} from '@mui/material';
import { Download, ContentCopy, SmartToy } from '@mui/icons-material';
import api from '../../services/api';
import { useNotification } from '../../app/hooks/useNotification';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { resolveApiBase } from '../../utils/apiBase';
import { buildVkBotWorkerPy } from '../../utils/vkBotWorkerScript';

type VkRow = {
  id: string;
  id_token: string;
  server_ip: string;
  selected_functions: string[];
  updated_at: string;
};


const FEATURE_DEFS: { id: string; label: string; hint: string }[] = [
  {
    id: 'metrics_digest',
    label: 'Сводка метрик',
    hint: 'Всего точек, уникальные имена, объём за 24 часа',
  },
  {
    id: 'latest_metrics',
    label: 'Последние значения',
    hint: 'До 8 имён с последним value и временем',
  },
  {
    id: 'alert_logs_digest',
    label: 'Ошибки в логах',
    hint: 'Счётчик error/critical/fatal за 24ч',
  },
  {
    id: 'host_metrics_hint',
    label: 'Подсказка по host-метрикам',
    hint: 'Текст про Linux-скрипт host.load1 / память / диск',
  },
  {
    id: 'connection_ok',
    label: 'Пинг связи',
    hint: 'Короткая отметка времени UTC',
  },
];

const defaultSelected = (): Record<string, boolean> => {
  const s: Record<string, boolean> = {};
  for (const f of FEATURE_DEFS) {
    s[f.id] = ['metrics_digest', 'latest_metrics', 'connection_ok'].includes(f.id);
  }
  return s;
};

function downloadText(filename: string, content: string, mime: string) {
  const blob = new Blob([content], { type: mime });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
  URL.revokeObjectURL(a.href);
}

export const VkBotModule: React.FC = () => {
  const { showError, showSuccess } = useNotification();
  const { workspace } = useWorkspace();
  const [rows, setRows] = useState<VkRow[]>([]);
  const [password, setPassword] = useState('');
  const [vkPeerId, setVkPeerId] = useState('');
  const [selected, setSelected] = useState<Record<string, boolean>>(defaultSelected);
  const [scriptBaseUrl, setScriptBaseUrl] = useState('');
  const [activeToken, setActiveToken] = useState<string | null>(null);

  const apiBase = useMemo(() => resolveApiBase(), []);
  const pullPath = '/api/waypoint/vk-bot/pull';

  const resolvedPublicBase = useMemo(() => {
    const u = scriptBaseUrl.trim();
    if (u) return u.replace(/\/$/, '');
    if (typeof window !== 'undefined') {
      if (apiBase.startsWith('http')) {
        return apiBase.replace(/\/api\/?$/, '').replace(/\/$/, '') || window.location.origin;
      }
      return window.location.origin;
    }
    return '';
  }, [apiBase, scriptBaseUrl]);

  const pullUrlFull = `${resolvedPublicBase}${pullPath}`;

  useEffect(() => {
    if (typeof window !== 'undefined' && !scriptBaseUrl) {
      setScriptBaseUrl(window.location.origin);
    }
  }, [scriptBaseUrl]);

  const load = async () => {
    try {
      const { data } = await api.get<VkRow[]>('/me/vk-module');
      const normalized = data.map((r) => ({
        ...r,
        selected_functions: Array.isArray(r.selected_functions)
          ? r.selected_functions
          : typeof r.selected_functions === 'string'
            ? []
            : [],
      }));
      setRows(normalized);
    } catch {
      showError('Не удалось загрузить привязки VK');
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const submit = async () => {
    if (password.length < 4) {
      showError('Пароль привязки не короче 4 символов');
      return;
    }
    if (!vkPeerId.trim() || !/^\d+$/.test(vkPeerId.trim())) {
      showError('Укажите VK peer_id (цифры: ваш id ВКонтакте, кому бот пишет)');
      return;
    }
    const selected_functions = FEATURE_DEFS.filter((f) => selected[f.id]).map((f) => f.id);
    if (selected_functions.length === 0) {
      showError('Выберите хотя бы одну функцию дайджеста');
      return;
    }
    try {
      const { data } = await api.post<{ id_token: string }>('/me/vk-module', {
        password,
        server_ip: vkPeerId.trim(),
        selected_functions,
      });
      showSuccess('Привязка создана — скачайте скрипт и .env');
      setActiveToken(data.id_token);
      setPassword('');
      await load();
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? String((e as { response?: { data?: { error?: string } } }).response?.data?.error ?? 'Ошибка')
          : 'Не удалось сохранить';
      showError(msg);
    }
  };

  const copyEnv = () => {
    const key = workspace.ingestApiKey ?? 'ВАШ_API_КЛЮЧ_ИЗ_КАБИНЕТА';
    const token = activeToken || rows[0]?.id_token || '';
    const lines = [
      `WAYPOINT_VK_PULL_URL=${pullUrlFull}`,
      `WAYPOINT_API_KEY=${key}`,
      `VK_MODULE_TOKEN=${token}`,
      'VK_MODULE_SECRET=пароль_который_задали_при_создании_привязки',
      'VK_GROUP_TOKEN=токен_группы_ВК_с_messages',
      `VK_PEER_ID=${vkPeerId.trim() || 'ваш_peer_id'}`,
    ];
    void navigator.clipboard.writeText(lines.join('\n'));
    showSuccess('.env скопирован в буфер');
  };

  const downloadPy = () => {
    if (!resolvedPublicBase) {
      showError('Укажите базовый URL консоли');
      return;
    }
    const py = buildVkBotWorkerPy({ waypointPublicBase: resolvedPublicBase });
    downloadText('waypoint_vk_digest.py', py, 'text/x-python;charset=utf-8');
    showSuccess('Скрипт сохранён');
  };

  const downloadEnvExample = () => {
    const key = workspace.ingestApiKey ?? '';
    const token = activeToken || rows[0]?.id_token || '';
    const peer = vkPeerId.trim() || rows[0]?.server_ip || '';
    const lines = [
      `# Подставьте секреты. Токен модуля: ${token || '(создайте привязку выше)'}`,
      `WAYPOINT_VK_PULL_URL=${pullUrlFull}`,
      `WAYPOINT_API_KEY=${key}`,
      `VK_MODULE_TOKEN=${token}`,
      'VK_MODULE_SECRET=',
      'VK_GROUP_TOKEN=',
      `VK_PEER_ID=${peer}`,
    ];
    downloadText('waypoint_vk.env.example', lines.join('\n'), 'text/plain;charset=utf-8');
  };

  return (
    <Box>
      <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1 }}>
        <SmartToy color="primary" />
        <Typography variant="h4" sx={{ fontWeight: 800 }}>
          Своё сообщество ВКонтакте
        </Typography>
      </Stack>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2, lineHeight: 1.7, maxWidth: 800 }}>
        Подключите <strong>свой</strong> токен группы VK: сообщения уходят <strong>только исходящим</strong> запросом с вашей
        машины или VPS (Python-скрипт). Платформа не хранит токен VK — только пароль привязки и выбранные блоки дайджеста.
        В консоли VK включите возможности бота и получите access token с правом <code>messages</code>.
      </Typography>

      <Alert severity="info" sx={{ mb: 2, maxWidth: 800 }}>
        Endpoint для скрипта: <code>POST {pullPath}</code> с заголовками{' '}
        <code>X-API-Key</code>, <code>X-VK-Module-Token</code>, <code>X-VK-Module-Secret</code>.
      </Alert>

      <Paper sx={{ p: 2.5, borderRadius: 2, mb: 3, maxWidth: 640 }}>
        <Typography variant="subtitle1" sx={{ fontWeight: 800, mb: 2 }}>
          1. Что присылает бот (только выбранное)
        </Typography>
        <FormGroup>
          {FEATURE_DEFS.map((f) => (
            <FormControlLabel
              key={f.id}
              control={
                <Checkbox
                  checked={!!selected[f.id]}
                  onChange={(_, v) => setSelected((s) => ({ ...s, [f.id]: v }))}
                />
              }
              label={
                <Box>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {f.label}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {f.hint}
                  </Typography>
                </Box>
              }
            />
          ))}
        </FormGroup>
        <Divider sx={{ my: 2 }} />
        <Typography variant="subtitle1" sx={{ fontWeight: 800, mb: 2 }}>
          2. Пароль привязки и peer_id
        </Typography>
        <Stack spacing={2}>
          <TextField
            type="password"
            label="Пароль привязки (для секрета в скрипте)"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            helperText="Не короче 4 символов; храните в .env на сервере, не коммитьте"
            fullWidth
          />
          <TextField
            label="VK peer_id получателя"
            value={vkPeerId}
            onChange={(e) => setVkPeerId(e.target.value)}
            helperText="Положительный id пользователя ВК (кому писать). Для группы — настройте разрешения бота."
            fullWidth
          />
          <TextField
            label="Базовый URL консоли (для генерации скрипта)"
            value={scriptBaseUrl}
            onChange={(e) => setScriptBaseUrl(e.target.value)}
            helperText="Обычно origin сайта, например https://metrics.example.com — без /api в конце"
            fullWidth
          />
          <Button variant="contained" onClick={() => void submit()}>
            Сохранить привязку и получить id_token
          </Button>
        </Stack>
      </Paper>

      <Paper sx={{ p: 2.5, borderRadius: 2, mb: 3, maxWidth: 640 }}>
        <Typography variant="subtitle1" sx={{ fontWeight: 800, mb: 1 }}>
          3. Код для скачивания
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2, lineHeight: 1.65 }}>
          После сохранения появится токен модуля (<code>vk_…</code>). Скачайте <code>waypoint_vk_digest.py</code> и шаблон{' '}
          <code>waypoint_vk.env.example</code>, перенесите переменные в <code>.env</code> на хосте и поставьте в cron или systemd
          timer (например раз в 15 минут).
        </Typography>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} flexWrap="wrap">
          <Button variant="outlined" startIcon={<Download />} onClick={downloadPy}>
            Скачать waypoint_vk_digest.py
          </Button>
          <Button variant="outlined" startIcon={<Download />} onClick={downloadEnvExample}>
            Скачать .env.example
          </Button>
          <Button variant="outlined" startIcon={<ContentCopy />} onClick={copyEnv}>
            Копировать env в буфер
          </Button>
        </Stack>
        {(activeToken || rows[0]?.id_token) && (
          <Typography variant="body2" sx={{ mt: 2, fontFamily: 'monospace', wordBreak: 'break-all' }}>
            Токен модуля: <strong>{activeToken ?? rows[0]?.id_token}</strong>
          </Typography>
        )}
      </Paper>

      <Typography variant="h6" sx={{ fontWeight: 800, mb: 1 }}>
        Активные привязки
      </Typography>
      <Stack spacing={1}>
        {rows.map((r) => (
          <Paper key={r.id} variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
            <Stack spacing={0.75}>
              <Stack direction="row" spacing={1} flexWrap="wrap" alignItems="center">
                <Chip size="small" label={r.id_token} />
                <Typography variant="body2" color="text.secondary">
                  peer_id: {r.server_ip}
                </Typography>
              </Stack>
              <Typography variant="caption" color="text.secondary" component="div">
                Функции:{' '}
                {Array.isArray(r.selected_functions) ? r.selected_functions.join(', ') : '—'}
              </Typography>
            </Stack>
          </Paper>
        ))}
        {rows.length === 0 && (
          <Typography variant="body2" color="text.secondary">
            Пока нет записей — создайте привязку выше.
          </Typography>
        )}
      </Stack>
    </Box>
  );
};
