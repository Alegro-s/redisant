import React, { useEffect, useState } from 'react';
import { Alert, Box, Button, LinearProgress, MenuItem, Paper, Stack, TextField, Typography } from '@mui/material';
import { DataGrid, GridColDef } from '@mui/x-data-grid';
import { useNavigate } from 'react-router-dom';
import api from '../../services/api';
import { useNotification } from '../../app/hooks/useNotification';

type Run = {
  id: string;
  label: string;
  git_url?: string | null;
  status: string;
  summary?: Record<string, unknown> | null;
  created_at: string;
  stage?: string;
  percent?: number;
  eta_seconds?: number;
};

type Summary = {
  stage?: string;
  percent?: number;
  eta_seconds?: number;
  eta_source?: string;
  files_count?: number;
  archive_size_bytes?: number;
  detected_stack?: string[];
  quality_tools?: {
    ruff_exit_code?: number;
    ruff_format_exit_code?: number;
    mypy_exit_code?: number;
    bandit_exit_code?: number;
  };
  python_files_count?: number;
  python_source_lines?: number;
  dependency_security?: {
    vulnerabilities_total?: number;
  };
};

type CompareRow = {
  id: string;
  label?: string;
  status?: string;
  created_at?: string;
  language?: string;
  strict_offline?: boolean;
  vulnerabilities_total?: number;
  tests_exit_code?: number;
  exit_code?: number;
  elapsed_seconds?: number;
};

export const ModuleTesting: React.FC = () => {
  const { showError, showSuccess } = useNotification();
  const navigate = useNavigate();
  const [runs, setRuns] = useState<Run[]>([]);
  const [label, setLabel] = useState('Анализ кода (ZIP)');
  const [zipFile, setZipFile] = useState<File | null>(null);
  const [activeRunId, setActiveRunId] = useState<string | null>(null);
  const [activeStatus, setActiveStatus] = useState<string>('');
  const [activeLogs, setActiveLogs] = useState<string>('');
  const [activeSummary, setActiveSummary] = useState<Summary | null>(null);
  const [language, setLanguage] = useState<'python' | 'rust'>('python');
  const [networkMode, setNetworkMode] = useState<'online' | 'strict'>('online');
  const [compareRows, setCompareRows] = useState<CompareRow[]>([]);
  const [sortBy, setSortBy] = useState<string>('created_at');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc');

  const load = async () => {
    try {
      const { data } = await api.get<Run[]>('/me/module-tests');
      setRuns(data);
    } catch {
      showError('Не удалось загрузить прогоны');
    }
  };

  useEffect(() => {
    void load();
    void loadCompare();
  }, []);

  useEffect(() => {
    void loadCompare();
  }, [sortBy, sortDir]);

  useEffect(() => {
    if (!activeRunId) return;
    const timer = setInterval(() => {
      void refreshRun(activeRunId);
      void refreshLogs(activeRunId);
    }, 3000);
    return () => clearInterval(timer);
  }, [activeRunId]);

  const loadCompare = async () => {
    try {
      const { data } = await api.get<{ rows: CompareRow[] }>(
        `/me/module-tests/compare?limit=50&sort_by=${encodeURIComponent(sortBy)}&sort_dir=${sortDir}`,
      );
      setCompareRows(data.rows ?? []);
    } catch {
    }
  };

  const runZip = async () => {
    if (!zipFile) {
      showError('Выберите ZIP-файл');
      return;
    }
    const fd = new FormData();
    fd.append('label', label.trim() || `${language.toUpperCase()} ZIP test`);
    fd.append('zip', zipFile);
    fd.append('language', language);
    fd.append('network_mode', networkMode);
    try {
      const { data } = await api.post<{ id: string; status: string }>('/me/module-tests/python/upload', fd, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      showSuccess('ZIP поставлен в очередь');
      setActiveRunId(data.id);
      setActiveStatus(data.status);
      await load();
      await refreshRun(data.id);
      await refreshLogs(data.id);
      await loadCompare();
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? String((e as { response?: { data?: { error?: string } } }).response?.data?.error ?? 'Ошибка')
          : 'Не удалось запустить ZIP-тест';
      showError(msg);
    }
  };

  const refreshRun = async (id: string) => {
    try {
      const { data } = await api.get<Run>(`/me/module-tests/${id}`);
      setActiveStatus(data.status);
      const s = (data.summary ?? null) as Summary | null;
      setActiveSummary({
        ...(s ?? {}),
        stage: data.stage ?? s?.stage,
        percent: data.percent ?? s?.percent,
        eta_seconds: data.eta_seconds ?? s?.eta_seconds,
      });
      await load();
    } catch {
    }
  };

  const refreshLogs = async (id: string) => {
    try {
      const { data } = await api.get<{ logs: string }>(`/me/module-tests/${id}/logs`);
      setActiveLogs(data.logs ?? '');
    } catch {
    }
  };

  const downloadArtifact = async (id: string, name: string) => {
    const { data } = await api.get(`/me/module-tests/${id}/artifact/${name}`, { responseType: 'blob' });
    const url = URL.createObjectURL(data);
    const a = document.createElement('a');
    a.href = url;
    a.download = name;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  };

  const exportCompareCsv = () => {
    if (!compareRows.length) return;
    const header = [
      'id',
      'label',
      'status',
      'created_at',
      'language',
      'strict_offline',
      'vulnerabilities_total',
      'tests_exit_code',
      'exit_code',
      'elapsed_seconds',
    ];
    const escapeCsv = (v: unknown) => `"${String(v ?? '').replace(/"/g, '""')}"`;
    const lines = [
      header.join(','),
      ...compareRows.map((r) =>
        [
          r.id,
          r.label,
          r.status,
          r.created_at,
          r.language,
          r.strict_offline,
          r.vulnerabilities_total,
          r.tests_exit_code,
          r.exit_code,
          r.elapsed_seconds,
        ]
          .map(escapeCsv)
          .join(','),
      ),
    ];
    const blob = new Blob([`\uFEFF${lines.join('\n')}`], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `module-test-compare-${Date.now()}.csv`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  };

  const exportComparePdf = () => {
    if (!compareRows.length) return;
    const rowsHtml = compareRows
      .map(
        (r) =>
          `<tr>
            <td>${r.label ?? r.id}</td>
            <td>${r.status ?? '—'}</td>
            <td>${r.language ?? '—'}</td>
            <td>${r.vulnerabilities_total ?? '—'}</td>
            <td>${r.tests_exit_code ?? '—'}</td>
            <td>${r.elapsed_seconds ?? '—'}</td>
          </tr>`,
      )
      .join('');
    const html = `<!doctype html><html><head><meta charset="utf-8" />
      <title>Lynx Compare Report</title>
      <style>
      body{font-family:Arial,sans-serif;padding:24px;color:#111}
      h1{font-size:20px;margin:0 0 12px}
      table{border-collapse:collapse;width:100%}
      th,td{border:1px solid #bbb;padding:8px;font-size:12px;text-align:left}
      th{background:#ece8ff}
      </style></head><body>
      <h1>Lynx Module Tests Compare</h1>
      <table><thead><tr><th>Label</th><th>Status</th><th>Lang</th><th>Vuln</th><th>Tests</th><th>Elapsed(s)</th></tr></thead>
      <tbody>${rowsHtml}</tbody></table></body></html>`;
    const w = window.open('', '_blank');
    if (!w) return;
    w.document.write(html);
    w.document.close();
    w.focus();
    w.print();
  };

  const compareColumns: GridColDef[] = [
    { field: 'label', headerName: 'Прогон', minWidth: 220, flex: 1 },
    { field: 'status', headerName: 'Статус', minWidth: 120 },
    { field: 'language', headerName: 'Язык', minWidth: 110 },
    { field: 'strict_offline', headerName: 'Strict', minWidth: 90, valueGetter: (p) => (p.value ? 'yes' : 'no') },
    { field: 'vulnerabilities_total', headerName: 'Vuln', type: 'number', minWidth: 90 },
    { field: 'tests_exit_code', headerName: 'Tests', type: 'number', minWidth: 90 },
    { field: 'exit_code', headerName: 'Exit', type: 'number', minWidth: 80 },
    { field: 'elapsed_seconds', headerName: 'Elapsed(s)', type: 'number', minWidth: 120 },
    {
      field: 'created_at',
      headerName: 'Создан',
      minWidth: 190,
      valueGetter: (p) => (p.value ? new Date(String(p.value)).toLocaleString() : '—'),
    },
  ];

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
        Тестирование модулей
      </Typography>
      <Alert severity="info" sx={{ mb: 2 }}>
        <Typography variant="body2" sx={{ mb: 1, fontWeight: 700 }}>
          Реальный анализ — только загрузка ZIP
        </Typography>
        <Typography variant="body2" component="div" sx={{ lineHeight: 1.65 }}>
          Runner в Docker прогоняет по вашему архиву: <strong>ruff</strong> (линт + проверка форматирования),{' '}
          <strong>mypy</strong>, <strong>bandit</strong>, <strong>pip-audit</strong> (уязвимости зависимостей), затем{' '}
          <strong>pytest</strong> (если есть тесты) или <strong>compileall</strong>. Итоги — в логах,{' '}
          <code>summary.json</code>, <code>quality.json</code>, PDF. На сервере с API должен быть{' '}
          <strong>Docker</strong> и доступ к образам <code>python:3.11-slim</code> / <code>rust:1.78</code> (как в{' '}
          <code>docker-compose.yml</code> с <code>docker.sock</code>).
        </Typography>
      </Alert>
      <Stack direction="row" spacing={1} sx={{ mb: 2 }}>
        <Button variant="outlined" onClick={() => navigate('/dashboard/module-testing/compare')}>
          Открыть сравнение версий алгоритма
        </Button>
      </Stack>

      <Paper sx={{ p: 2.5, borderRadius: 2, mb: 3 }}>
        <Stack spacing={2} sx={{ maxWidth: 520 }}>
          <TextField label="Название прогона" value={label} onChange={(e) => setLabel(e.target.value)} />
          <TextField
            select
            label="Тип проекта"
            value={language}
            onChange={(e) => setLanguage(e.target.value as 'python' | 'rust')}
          >
            <MenuItem value="python">Python</MenuItem>
            <MenuItem value="rust">Rust (движок/алгоритм)</MenuItem>
          </TextField>
          <TextField
            select
            label="Режим сети runner"
            value={networkMode}
            onChange={(e) => setNetworkMode(e.target.value as 'online' | 'strict')}
          >
            <MenuItem value="online">Online (разрешена сеть для установки tools)</MenuItem>
            <MenuItem value="strict">Strict (без сети, дипломный стенд)</MenuItem>
          </TextField>
          <Button variant="outlined" component="label">
            {zipFile ? `ZIP: ${zipFile.name}` : 'Выбрать ZIP (Python/Rust проект)'}
            <input
              type="file"
              hidden
              accept=".zip,application/zip"
              onChange={(e) => setZipFile(e.target.files?.[0] ?? null)}
            />
          </Button>
          <Button variant="contained" color="primary" onClick={() => void runZip()}>
            Запустить ZIP-тест в runner (реальный анализ)
          </Button>
          <Paper
            variant="outlined"
            onDragOver={(e) => e.preventDefault()}
            onDrop={(e) => {
              e.preventDefault();
              const f = e.dataTransfer.files?.[0];
              if (f) setZipFile(f);
            }}
            sx={{
              p: 2,
              borderStyle: 'dashed',
              borderColor: 'primary.main',
              bgcolor: 'action.hover',
              textAlign: 'center',
            }}
          >
            Перетащите ZIP сюда для тестирования
          </Paper>
        </Stack>
      </Paper>

      <Paper sx={{ p: 2.5, borderRadius: 2, mb: 3 }}>
        <Typography variant="h6" sx={{ mb: 1 }}>
          Активный прогон
        </Typography>
        <Typography variant="body2" color="text.secondary">
          ID: {activeRunId ?? '—'}
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
          Статус: {activeStatus || '—'}
        </Typography>
        {activeSummary?.percent !== undefined && (
          <Box sx={{ mb: 1.5 }}>
            <Typography variant="caption" color="text.secondary">
              Этап: {activeSummary.stage ?? '—'} · {activeSummary.percent}%
            </Typography>
            <LinearProgress variant="determinate" value={Math.max(0, Math.min(100, activeSummary.percent ?? 0))} />
            {typeof activeSummary.eta_seconds === 'number' && (
              <Typography variant="caption" color="text.secondary">
                ETA: ~{Math.max(0, Math.round(activeSummary.eta_seconds / 60))} мин
              </Typography>
            )}
          </Box>
        )}
        {activeSummary && (
          <Stack direction={{ xs: 'column', md: 'row' }} spacing={1.5} sx={{ mb: 1.5 }}>
            <Paper variant="outlined" sx={{ p: 1, minWidth: 170 }}>
              <Typography variant="caption" color="text.secondary">
                Файлы (все / .py / строк Python)
              </Typography>
              <Typography variant="h6">
                {activeSummary.files_count ?? 0}
                {activeSummary.python_files_count != null
                  ? ` / ${activeSummary.python_files_count} / ${activeSummary.python_source_lines ?? 0}`
                  : ''}
              </Typography>
            </Paper>
            <Paper variant="outlined" sx={{ p: 1, minWidth: 170 }}>
              <Typography variant="caption" color="text.secondary">
                Уязвимости
              </Typography>
              <Typography variant="h6">{activeSummary.dependency_security?.vulnerabilities_total ?? 0}</Typography>
            </Paper>
            <Paper variant="outlined" sx={{ p: 1, minWidth: 220 }}>
              <Typography variant="caption" color="text.secondary">
                Quality tools exit
              </Typography>
              <Typography variant="body2" sx={{ fontFamily: 'monospace' }} component="div">
                ruff={activeSummary.quality_tools?.ruff_exit_code ?? '-'}; fmt=
                {activeSummary.quality_tools?.ruff_format_exit_code ?? '-'}; mypy=
                {activeSummary.quality_tools?.mypy_exit_code ?? '-'}; bandit=
                {activeSummary.quality_tools?.bandit_exit_code ?? '-'}
              </Typography>
            </Paper>
          </Stack>
        )}
        {activeRunId && (
          <Stack direction="row" spacing={1} sx={{ mb: 1.5, flexWrap: 'wrap' }}>
            <Button size="small" variant="outlined" onClick={() => void downloadArtifact(activeRunId, 'summary.json')}>
              Скачать summary.json
            </Button>
            <Button size="small" variant="outlined" onClick={() => void downloadArtifact(activeRunId, 'quality.json')}>
              Скачать quality.json
            </Button>
            <Button size="small" variant="outlined" onClick={() => void downloadArtifact(activeRunId, 'deps_security.json')}>
              Скачать deps_security.json
            </Button>
            <Button size="small" variant="outlined" onClick={() => void downloadArtifact(activeRunId, 'diploma_report.json')}>
              Скачать diploma_report.json
            </Button>
            <Button size="small" variant="contained" onClick={() => void downloadArtifact(activeRunId, 'diploma_report.pdf')}>
              Скачать PDF
            </Button>
          </Stack>
        )}
        <Paper variant="outlined" sx={{ p: 1.5, borderRadius: 1, bgcolor: '#0f1118' }}>
          <Typography
            component="pre"
            sx={{ m: 0, whiteSpace: 'pre-wrap', fontFamily: 'monospace', fontSize: 12, color: '#c7d2fe' }}
          >
            {activeLogs || 'Логи появятся после старта runner.'}
          </Typography>
        </Paper>
      </Paper>

      <Typography variant="h6" sx={{ mb: 1 }}>
        История
      </Typography>
      <Stack spacing={1}>
        {runs.map((r) => (
          <Paper key={r.id} variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
            <Typography variant="subtitle2">{r.label}</Typography>
            <Typography variant="caption" color="text.secondary">
              {r.status} · {new Date(r.created_at).toLocaleString()}
            </Typography>
            {r.summary && (
              <Typography variant="body2" sx={{ mt: 1, fontFamily: 'monospace', fontSize: 12 }}>
                {JSON.stringify(r.summary)}
              </Typography>
            )}
          </Paper>
        ))}
        {runs.length === 0 && (
          <Typography variant="body2" color="text.secondary">
            Пока нет прогонов
          </Typography>
        )}
      </Stack>
      <Paper
        sx={{
          p: 2.5,
          borderRadius: 2,
          mt: 3,
          background: (t) => `linear-gradient(180deg, ${t.palette.background.paper} 0%, ${t.palette.action.hover} 100%)`,
        }}
      >
        <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 1 }}>
          <Typography variant="h6">Сравнение прогонов</Typography>
          <Stack direction="row" spacing={1}>
            <TextField
              select
              size="small"
              label="Сортировка"
              value={sortBy}
              onChange={(e) => setSortBy(e.target.value)}
              sx={{ minWidth: 170 }}
            >
              <MenuItem value="created_at">Дата</MenuItem>
              <MenuItem value="label">Название</MenuItem>
              <MenuItem value="status">Статус</MenuItem>
              <MenuItem value="language">Язык</MenuItem>
              <MenuItem value="vulnerabilities_total">Уязвимости</MenuItem>
              <MenuItem value="tests_exit_code">Тесты</MenuItem>
              <MenuItem value="elapsed_seconds">Время</MenuItem>
            </TextField>
            <TextField
              select
              size="small"
              label="Порядок"
              value={sortDir}
              onChange={(e) => setSortDir(e.target.value as 'asc' | 'desc')}
              sx={{ minWidth: 130 }}
            >
              <MenuItem value="desc">По убыв.</MenuItem>
              <MenuItem value="asc">По возр.</MenuItem>
            </TextField>
            <Button size="small" variant="outlined" onClick={() => void loadCompare()}>
              Обновить
            </Button>
          </Stack>
        </Stack>
        {compareRows.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            Пока нет данных для сравнения
          </Typography>
        ) : (
          <Box sx={{ width: '100%' }}>
            <Stack direction="row" spacing={1} sx={{ mb: 1 }}>
              <Button size="small" variant="outlined" onClick={exportCompareCsv}>
                Экспорт CSV
              </Button>
              <Button size="small" variant="contained" onClick={exportComparePdf}>
                Экспорт PDF
              </Button>
            </Stack>
            <DataGrid
              rows={compareRows}
              columns={compareColumns}
              autoHeight
              disableRowSelectionOnClick
              pageSizeOptions={[5, 10, 25, 50]}
              initialState={{ pagination: { paginationModel: { pageSize: 10, page: 0 } } }}
            />
          </Box>
        )}
      </Paper>
    </Box>
  );
};
