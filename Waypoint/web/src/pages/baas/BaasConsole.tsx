import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Divider,
  MenuItem,
  Paper,
  Tab,
  Tabs,
  TextField,
  Typography,
} from '@mui/material';
import {
  createBaasTable,
  createBucket,
  deleteBaasRow,
  downloadBaasObject,
  fetchBaasBootstrap,
  insertBaasRow,
  listBaasRestRows,
  listBaasTables,
  listBuckets,
  runBaasSql,
  uploadBaasObject,
} from '../../services/baas.service';
import { deepseekChat } from '../../services/waypoint-chat.service';
import { useNotification } from '../../app/hooks/useNotification';

export const BaasConsole: React.FC = () => {
  const { showError, showSuccess } = useNotification();
  const [tab, setTab] = useState(0);
  const [loading, setLoading] = useState(false);
  const [schemaName, setSchemaName] = useState<string | null>(null);
  const [sql, setSql] = useState('SELECT 1 AS ok');
  const [sqlResult, setSqlResult] = useState<string>('');
  const [tables, setTables] = useState<string[]>([]);
  const [newTable, setNewTable] = useState('items');
  const [restTable, setRestTable] = useState('');
  const [restRows, setRestRows] = useState<Record<string, unknown>[]>([]);
  const [restJson, setRestJson] = useState('{"hello":"world"}');
  const [buckets, setBuckets] = useState<{ id: string; name: string; public_read: boolean }[]>([]);
  const [newBucket, setNewBucket] = useState('default');
  const [uploadBucket, setUploadBucket] = useState('');
  const [objectKey, setObjectKey] = useState('demo.txt');
  const [chatIn, setChatIn] = useState('Кратко опиши, что такое JSONB в PostgreSQL.');
  const [chatOut, setChatOut] = useState('');

  
  const loadBaasBootstrap = useCallback(async () => {
    setLoading(true);
    try {
      const b = await fetchBaasBootstrap();
      setSchemaName(b.schema_name);
      setTables(b.tables);
      setBuckets(b.buckets);
      setRestTable((prev) => prev || (b.tables[0] ?? ''));
      setUploadBucket((prev) => prev || (b.buckets[0]?.name ?? ''));
    } catch {
      showError('Не удалось загрузить BaaS (схема / таблицы / buckets)');
      setSchemaName(null);
      setTables([]);
      setBuckets([]);
    } finally {
      setLoading(false);
    }
  }, [showError]);

  const refreshTables = useCallback(async () => {
    try {
      const t = await listBaasTables();
      setTables(t);
      setRestTable((prev) => prev || (t[0] ?? ''));
    } catch {
      showError('Список таблиц недоступен');
    }
  }, [showError]);

  const refreshBuckets = useCallback(async () => {
    try {
      const list = await listBuckets();
      setBuckets(list);
      setUploadBucket((prev) => prev || (list[0]?.name ?? ''));
    } catch {
      showError('Список bucket недоступен');
    }
  }, [showError]);

  useEffect(() => {
    void loadBaasBootstrap();
  }, [loadBaasBootstrap]);

  const onRunSql = async () => {
    setLoading(true);
    setSqlResult('');
    try {
      const r = await runBaasSql(sql);
      setSqlResult(JSON.stringify(r, null, 2));
    } catch (e: unknown) {
      const msg = e && typeof e === 'object' && 'response' in e ? String((e as { response?: { data?: { error?: string } } }).response?.data?.error) : 'SQL error';
      setSqlResult(msg);
      showError('Ошибка SQL');
    } finally {
      setLoading(false);
    }
  };

  const onCreateTable = async () => {
    setLoading(true);
    try {
      await createBaasTable(newTable.trim());
      showSuccess('Таблица создана');
      await refreshTables();
    } catch {
      showError('CREATE table не удался (нужен WM_BAAS_SQL_WRITE / ADMIN_ALLOW_SQL_WRITE на сервере)');
    } finally {
      setLoading(false);
    }
  };

  const onLoadRest = async () => {
    if (!restTable) return;
    setLoading(true);
    try {
      const rows = await listBaasRestRows(restTable);
      setRestRows(rows);
    } catch {
      showError('REST: не удалось прочитать строки');
    } finally {
      setLoading(false);
    }
  };

  const onInsertRest = async () => {
    if (!restTable) return;
    setLoading(true);
    try {
      const obj = JSON.parse(restJson) as Record<string, unknown>;
      await insertBaasRow(restTable, obj);
      showSuccess('Строка добавлена');
      await onLoadRest();
    } catch {
      showError('Некорректный JSON или ошибка вставки');
    } finally {
      setLoading(false);
    }
  };

  const onDeleteRow = async (id: string) => {
    if (!restTable) return;
    setLoading(true);
    try {
      await deleteBaasRow(restTable, id);
      showSuccess('Удалено');
      await onLoadRest();
    } catch {
      showError('Удаление не удалось');
    } finally {
      setLoading(false);
    }
  };

  const onCreateBucket = async () => {
    setLoading(true);
    try {
      await createBucket(newBucket.trim());
      showSuccess('Bucket создан');
      await refreshBuckets();
    } catch {
      showError('Bucket не создан');
    } finally {
      setLoading(false);
    }
  };

  const onUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f || !uploadBucket) return;
    setLoading(true);
    try {
      await uploadBaasObject(uploadBucket, objectKey.trim() || f.name, f);
      showSuccess('Файл загружен');
    } catch {
      showError('Загрузка не удалась');
    } finally {
      setLoading(false);
      e.target.value = '';
    }
  };

  const onDownload = async () => {
    if (!uploadBucket || !objectKey.trim()) return;
    setLoading(true);
    try {
      const blob = await downloadBaasObject(uploadBucket, objectKey.trim());
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = objectKey.split('/').pop() || 'download';
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      showError('Скачивание не удалось');
    } finally {
      setLoading(false);
    }
  };

  const onChat = async () => {
    setLoading(true);
    setChatOut('');
    try {
      const r = await deepseekChat([{ role: 'user', content: chatIn }]);
      setChatOut(JSON.stringify(r, null, 2));
    } catch {
      showError('Чат недоступен (проверьте DEEPSEEK_API_KEY на сервере)');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box sx={{ p: 2, maxWidth: 1100, mx: 'auto' }}>
      <Typography variant="h5" gutterBottom>
        WaypointMetric BaaS
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Часть WaypointMetric (BaaS для сайтов и приложений), не панель движка. Изолированная схема PostgreSQL на аккаунт,
        SQL с ограничениями, JSONB-таблицы, объекты в локальном storage.
      </Typography>

      {schemaName && (
        <Alert severity="info" sx={{ mb: 2 }}>
          Активная схема: <strong>{schemaName}</strong>
        </Alert>
      )}

      <Paper sx={{ mb: 2 }}>
        <Tabs value={tab} onChange={(_, v) => setTab(v)} variant="scrollable">
          <Tab label="SQL" />
          <Tab label="Таблицы / REST" />
          <Tab label="Storage" />
          <Tab label="AI (DeepSeek)" />
        </Tabs>
        <Divider />
        <Box sx={{ p: 2 }}>
          {tab === 0 && (
            <Box>
              <TextField
                fullWidth
                multiline
                minRows={6}
                value={sql}
                onChange={(e) => setSql(e.target.value)}
                sx={{ mb: 1, fontFamily: 'monospace' }}
              />
              <Button variant="contained" onClick={() => void onRunSql()} disabled={loading}>
                Выполнить
              </Button>
              {sqlResult && (
                <TextField
                  fullWidth
                  multiline
                  minRows={8}
                  value={sqlResult}
                  sx={{ mt: 2, fontFamily: 'monospace' }}
                  InputProps={{ readOnly: true }}
                />
              )}
            </Box>
          )}

          {tab === 1 && (
            <Box>
              <Typography variant="subtitle2">Новая JSONB-таблица</Typography>
              <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', my: 1 }}>
                <TextField size="small" label="Имя" value={newTable} onChange={(e) => setNewTable(e.target.value)} />
                <Button variant="outlined" onClick={() => void onCreateTable()} disabled={loading}>
                  Создать
                </Button>
                <Button variant="text" onClick={() => void refreshTables()} disabled={loading}>
                  Обновить список
                </Button>
              </Box>
              <Typography variant="caption" color="text.secondary">
                Таблицы: {tables.join(', ') || '—'}
              </Typography>
              <Divider sx={{ my: 2 }} />
              <Typography variant="subtitle2">REST (data JSONB)</Typography>
              <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', my: 1 }}>
                <TextField
                  select
                  size="small"
                  label="Таблица"
                  value={restTable}
                  onChange={(e) => setRestTable(e.target.value)}
                  sx={{ minWidth: 160 }}
                >
                  {tables.map((t) => (
                    <MenuItem key={t} value={t}>
                      {t}
                    </MenuItem>
                  ))}
                </TextField>
                <Button variant="outlined" onClick={() => void onLoadRest()} disabled={loading || !restTable}>
                  Загрузить строки
                </Button>
              </Box>
              <TextField
                fullWidth
                multiline
                minRows={3}
                label="JSON для вставки в data"
                value={restJson}
                onChange={(e) => setRestJson(e.target.value)}
                sx={{ mb: 1, fontFamily: 'monospace' }}
              />
              <Button variant="contained" onClick={() => void onInsertRest()} disabled={loading || !restTable}>
                INSERT
              </Button>
              <Box sx={{ mt: 2 }}>
                {restRows.map((row) => (
                  <Paper key={String(row.id)} variant="outlined" sx={{ p: 1, mb: 1 }}>
                    <Typography variant="caption" component="pre" sx={{ whiteSpace: 'pre-wrap' }}>
                      {JSON.stringify(row, null, 2)}
                    </Typography>
                    <Button size="small" color="error" onClick={() => void onDeleteRow(String(row.id))}>
                      Удалить
                    </Button>
                  </Paper>
                ))}
              </Box>
            </Box>
          )}

          {tab === 2 && (
            <Box>
              <Typography variant="subtitle2">Buckets</Typography>
              <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap', my: 1 }}>
                <TextField size="small" label="Имя bucket" value={newBucket} onChange={(e) => setNewBucket(e.target.value)} />
                <Button variant="outlined" onClick={() => void onCreateBucket()} disabled={loading}>
                  Создать bucket
                </Button>
              </Box>
              <TextField
                select
                size="small"
                label="Bucket для файла"
                value={uploadBucket}
                onChange={(e) => setUploadBucket(e.target.value)}
                sx={{ minWidth: 200, mr: 1, mt: 1 }}
              >
                {buckets.map((b) => (
                  <MenuItem key={b.id} value={b.name}>
                    {b.name}
                  </MenuItem>
                ))}
              </TextField>
              <TextField
                size="small"
                label="Ключ объекта"
                value={objectKey}
                onChange={(e) => setObjectKey(e.target.value)}
                sx={{ mt: 1, mr: 1 }}
              />
              <Button variant="contained" component="label" sx={{ mt: 1 }} disabled={loading || !uploadBucket}>
                Загрузить файл
                <input type="file" hidden onChange={(e) => void onUpload(e)} />
              </Button>
              <Button variant="outlined" sx={{ mt: 1, ml: 1 }} onClick={() => void onDownload()} disabled={loading}>
                Скачать по ключу
              </Button>
            </Box>
          )}

          {tab === 3 && (
            <Box>
              <Alert severity="warning" sx={{ mb: 2 }}>
                Прокси на сервере: нужен <code>DEEPSEEK_API_KEY</code>. Ответ приходит в сыром JSON (OpenAI-совместимый).
              </Alert>
              <TextField
                fullWidth
                multiline
                minRows={3}
                value={chatIn}
                onChange={(e) => setChatIn(e.target.value)}
                sx={{ mb: 1 }}
              />
              <Button variant="contained" onClick={() => void onChat()} disabled={loading}>
                Отправить
              </Button>
              {chatOut && (
                <TextField
                  fullWidth
                  multiline
                  minRows={10}
                  value={chatOut}
                  sx={{ mt: 2, fontFamily: 'monospace' }}
                  InputProps={{ readOnly: true }}
                />
              )}
            </Box>
          )}
        </Box>
      </Paper>

      {loading && (
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 2 }}>
          <CircularProgress size={28} />
        </Box>
      )}
    </Box>
  );
};
