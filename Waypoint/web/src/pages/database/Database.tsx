import React, { useCallback, useEffect, useState } from 'react';
import {
  Box,
  Button,
  TextField,
  Typography,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Alert,
  CircularProgress,
  FormControlLabel,
  Switch,
  useTheme,
  Select,
  MenuItem,
  FormControl,
} from '@mui/material';
import { PlayArrow as RunIcon, Save as SaveIcon, History as HistoryIcon } from '@mui/icons-material';
import api from '../../services/api';
import { useNotification } from '../../app/hooks/useNotification';
import { useAuth } from '../../app/contexts/AuthContext';
import { useSnackbar } from 'notistack';
import { SchemaErDiagram } from './SchemaErDiagram';

const HOSTING_STATUSES = ['requested', 'processing', 'done', 'cancelled'] as const;

export const Database: React.FC = () => {
  const { isAdmin } = useAuth();
  const [query, setQuery] = useState('SELECT current_timestamp AS server_time;');
  const [result, setResult] = useState<any[] | null>(null);
  const [columns, setColumns] = useState<string[]>([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [readOnly, setReadOnly] = useState(true);
  const [agentSchema, setAgentSchema] = useState<unknown>(null);
  const [agentSeen, setAgentSeen] = useState<string | null>(null);
  const [agentLoading, setAgentLoading] = useState(false);
  const [hostingRows, setHostingRows] = useState<
    {
      id: string;
      user_id: string;
      status: string;
      note: string | null;
      created_at: string;
      updated_at?: string;
    }[]
  >([]);
  const [hostingLoading, setHostingLoading] = useState(false);
  const [hostingSavingId, setHostingSavingId] = useState<string | null>(null);
  const theme = useTheme();
  const { showSuccess, showError } = useNotification();
  const { enqueueSnackbar } = useSnackbar();

  const loadAgentSchema = useCallback(async () => {
    setAgentLoading(true);
    try {
      const r = await api.get('/me/agent/schema');
      setAgentSchema(r.data?.schema ?? null);
      setAgentSeen(r.data?.agent_last_seen ?? null);
      showSuccess('Схема агента обновлена');
    } catch (err: unknown) {
      const ax = err as { response?: { data?: { error?: string } } };
      showError(ax.response?.data?.error || 'Не удалось загрузить схему агента');
    } finally {
      setAgentLoading(false);
    }
  }, [showError, showSuccess]);

  const loadHosting = useCallback(async () => {
    if (!isAdmin) return;
    setHostingLoading(true);
    try {
      const r = await api.get('/admin/hosting-requests');
      setHostingRows(Array.isArray(r.data) ? r.data : []);
    } catch {
      showError('Не удалось загрузить заявки на хостинг');
    } finally {
      setHostingLoading(false);
    }
  }, [isAdmin, showError]);

  useEffect(() => {
    if (isAdmin) void loadHosting();
  }, [isAdmin, loadHosting]);

  const patchHostingStatus = useCallback(
    async (id: string, status: string) => {
      if (!HOSTING_STATUSES.includes(status as (typeof HOSTING_STATUSES)[number])) return;
      setHostingSavingId(id);
      try {
        await api.patch(`/admin/hosting-requests/${id}`, { status });
        showSuccess('Статус заявки обновлён');
        await loadHosting();
      } catch (err: unknown) {
        const ax = err as { response?: { data?: { error?: string } } };
        showError(ax.response?.data?.error || 'Не удалось обновить статус');
      } finally {
        setHostingSavingId(null);
      }
    },
    [loadHosting, showError, showSuccess],
  );

  const handleRun = async () => {
    if (!query.trim()) return;
    setError('');
    setLoading(true);

    const url = isAdmin ? '/admin/db/query' : '/me/db/query';
    const payload = isAdmin
      ? { query: query.trim(), read_only: readOnly }
      : { query: query.trim(), read_only: true };

    try {
      const response = await api.post(url, payload);

      if (response.data.rows) {
        setResult(response.data.rows);
        setColumns(response.data.columns || []);
        showSuccess(`Выполнено: ${response.data.rows.length} строк`);
        enqueueSnackbar(`SQL: ${response.data.rows.length} строк`, { variant: 'success' });
      } else {
        setResult(null);
        setColumns([]);
        showSuccess('Запрос выполнен');
      }
    } catch (err: unknown) {
      const ax = err as { response?: { data?: { error?: string } }; message?: string; code?: string };
      const net =
        !ax.response &&
        (ax.code === 'ERR_NETWORK' || /network|ERR_CONNECTION|failed/i.test(ax.message ?? ''));
      const msg = net
        ? 'Нет связи с облаком. Откройте сайт в браузере и проверьте подключение к интернету.'
        : ax.response?.data?.error || 'Не удалось выполнить запрос.';
      setError(msg);
      showError(msg);
      enqueueSnackbar(msg, { variant: 'error', autoHideDuration: 10000 });
    } finally {
      setLoading(false);
    }
  };

  const schemaTableCount =
    agentSchema && typeof agentSchema === 'object' && agentSchema !== null
      ? Object.keys(agentSchema as object).length
      : 0;

  return (
    <Box>
      <Box sx={{ mb: 3 }}>
        <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
          База данных (SQL)
        </Typography>
        <Typography variant="body2" color="text.secondary">
          {isAdmin
            ? 'Режим администратора: доступны запросы согласно политике сервера (read-only / запись при явном разрешении).'
            : 'Только безопасные SELECT / WITH (чтение). Запись и администрирование — у роли admin.'}
        </Typography>
      </Box>

      <Paper sx={{ p: 3, borderRadius: 3, mb: 3 }}>
        <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
          Кэш схемы агента (диаграмма)
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Последний heartbeat агента: {agentSeen ?? '—'}. Таблиц в снимке: {schemaTableCount}.
        </Typography>
        <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap', mb: 2 }}>
          <Button
            variant="outlined"
            size="small"
            disabled={agentLoading}
            onClick={() => void loadAgentSchema()}
          >
            {agentLoading ? <CircularProgress size={20} /> : 'Загрузить схему'}
          </Button>
        </Box>
        {agentSchema != null && (
          <>
            <Box sx={{ mb: 2 }}>
              <SchemaErDiagram schema={agentSchema} />
            </Box>
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.5 }}>
              Сырой JSON снимка
            </Typography>
            <Box
              component="pre"
              sx={{
                maxHeight: 220,
                overflow: 'auto',
                p: 2,
                bgcolor: theme.palette.action.hover,
                borderRadius: 1,
                fontSize: 12,
              }}
            >
              {JSON.stringify(agentSchema, null, 2)}
            </Box>
          </>
        )}
      </Paper>

      {isAdmin && (
        <Paper sx={{ p: 3, borderRadius: 3, mb: 3 }}>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>
              Заявки на аренду сервера
            </Typography>
            <Button size="small" variant="outlined" disabled={hostingLoading} onClick={() => void loadHosting()}>
              {hostingLoading ? <CircularProgress size={20} /> : 'Обновить'}
            </Button>
          </Box>
          <TableContainer>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Статус</TableCell>
                  <TableCell>User ID</TableCell>
                  <TableCell>Примечание</TableCell>
                  <TableCell>Создано</TableCell>
                  <TableCell>Обновлено</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {hostingRows.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={5}>
                      <Typography variant="body2" color="text.secondary">
                        Нет заявок
                      </Typography>
                    </TableCell>
                  </TableRow>
                ) : (
                  hostingRows.map((h) => (
                    <TableRow key={h.id}>
                      <TableCell sx={{ minWidth: 160 }}>
                        <FormControl size="small" fullWidth disabled={hostingSavingId === h.id}>
                          <Select
                            value={h.status}
                            onChange={(e) => {
                              const v = e.target.value;
                              if (v !== h.status) void patchHostingStatus(h.id, v);
                            }}
                          >
                            {HOSTING_STATUSES.map((s) => (
                              <MenuItem key={s} value={s}>
                                {s}
                              </MenuItem>
                            ))}
                          </Select>
                        </FormControl>
                        {hostingSavingId === h.id ? (
                          <CircularProgress size={16} sx={{ display: 'block', mt: 0.5 }} />
                        ) : null}
                      </TableCell>
                      <TableCell sx={{ fontFamily: 'monospace', fontSize: 12 }}>{h.user_id}</TableCell>
                      <TableCell>{h.note ?? '—'}</TableCell>
                      <TableCell>{h.created_at}</TableCell>
                      <TableCell>{h.updated_at ?? '—'}</TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </TableContainer>
        </Paper>
      )}

      <Paper sx={{ p: 3, borderRadius: 3, mb: 3 }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2, flexWrap: 'wrap', gap: 1 }}>
          <Typography variant="h6" sx={{ fontWeight: 600 }}>
            Редактор запроса
          </Typography>
          {isAdmin ? (
            <FormControlLabel
              control={
                <Switch
                  checked={readOnly}
                  onChange={(e) => setReadOnly(e.target.checked)}
                  color="primary"
                />
              }
              label="Только чтение (SELECT)"
            />
          ) : (
            <Typography variant="caption" color="text.secondary">
              Режим пользователя: всегда только чтение
            </Typography>
          )}
        </Box>

        <TextField
          label="SQL"
          multiline
          rows={8}
          fullWidth
          variant="outlined"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          sx={{ mb: 2, fontFamily: 'monospace' }}
          placeholder="SELECT …"
        />

        <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap' }}>
          <Button
            variant="contained"
            startIcon={loading ? <CircularProgress size={20} /> : <RunIcon />}
            onClick={() => void handleRun()}
            disabled={loading}
          >
            Выполнить
          </Button>
          <Button variant="outlined" startIcon={<SaveIcon />} disabled>
            Сохранить
          </Button>
          <Button variant="outlined" startIcon={<HistoryIcon />} disabled>
            История
          </Button>
        </Box>
      </Paper>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}

      {result && result.length > 0 && (
        <Paper sx={{ borderRadius: 3, overflow: 'hidden' }}>
          <TableContainer sx={{ maxHeight: 500 }}>
            <Table stickyHeader size="small">
              <TableHead>
                <TableRow sx={{ bgcolor: theme.palette.background.default }}>
                  {columns.map((col) => (
                    <TableCell
                      key={col}
                      sx={{
                        fontWeight: 600,
                        bgcolor: theme.palette.background.paper,
                      }}
                    >
                      {col}
                    </TableCell>
                  ))}
                </TableRow>
              </TableHead>
              <TableBody>
                {result.map((row, idx) => (
                  <TableRow key={idx} hover>
                    {columns.map((col) => (
                      <TableCell key={col}>
                        {row[col] !== null && row[col] !== undefined
                          ? typeof row[col] === 'object'
                            ? JSON.stringify(row[col])
                            : String(row[col])
                          : 'NULL'}
                      </TableCell>
                    ))}
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        </Paper>
      )}

      {result && result.length === 0 && (
        <Alert severity="info">Запрос выполнен. Строк нет.</Alert>
      )}
    </Box>
  );
};
