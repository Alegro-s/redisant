import React, { useEffect, useMemo, useState } from 'react';
import { Box, Button, MenuItem, Paper, Stack, TextField, Typography } from '@mui/material';
import { DataGrid, GridColDef } from '@mui/x-data-grid';
import { Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis, CartesianGrid, Legend } from 'recharts';
import api from '../../services/api';
import { useNotification } from '../../app/hooks/useNotification';

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

export const AlgorithmCompare: React.FC = () => {
  const { showError } = useNotification();
  const [rows, setRows] = useState<CompareRow[]>([]);
  const [sortBy, setSortBy] = useState<string>('created_at');
  const [sortDir, setSortDir] = useState<'asc' | 'desc'>('desc');

  const load = async () => {
    try {
      const { data } = await api.get<{ rows: CompareRow[] }>(
        `/me/module-tests/compare?limit=100&sort_by=${encodeURIComponent(sortBy)}&sort_dir=${sortDir}`,
      );
      setRows(data.rows ?? []);
    } catch {
      showError('Не удалось загрузить сравнение прогонов');
    }
  };

  useEffect(() => {
    void load();
  }, [sortBy, sortDir]);

  const timelineData = useMemo(
    () =>
      [...rows]
        .sort((a, b) => new Date(a.created_at ?? 0).getTime() - new Date(b.created_at ?? 0).getTime())
        .map((r, idx) => ({
          idx: idx + 1,
          label: r.label ?? r.id,
          vulnerabilities_total: r.vulnerabilities_total ?? 0,
          elapsed_seconds: r.elapsed_seconds ?? 0,
          tests_exit_code: r.tests_exit_code ?? 0,
        })),
    [rows],
  );

  const exportDiplomaJson = () => {
    const payload = {
      title: 'Lynx Diploma Compare Report',
      generated_at: new Date().toISOString(),
      metrics: {
        total_runs: rows.length,
        avg_vulnerabilities:
          rows.length > 0
            ? rows.reduce((acc, r) => acc + Number(r.vulnerabilities_total ?? 0), 0) / rows.length
            : 0,
        avg_elapsed_seconds:
          rows.length > 0 ? rows.reduce((acc, r) => acc + Number(r.elapsed_seconds ?? 0), 0) / rows.length : 0,
      },
      runs: rows,
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `nexus-diploma-compare-${Date.now()}.json`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  };

  const exportDiplomaPdf = () => {
    const htmlRows = rows
      .map(
        (r) =>
          `<tr><td>${r.label ?? r.id}</td><td>${r.status ?? '—'}</td><td>${r.language ?? '—'}</td><td>${
            r.vulnerabilities_total ?? '—'
          }</td><td>${r.tests_exit_code ?? '—'}</td><td>${r.elapsed_seconds ?? '—'}</td></tr>`,
      )
      .join('');
    const html = `<!doctype html><html><head><meta charset="utf-8"/>
      <title>Lynx Diploma Compare Report</title>
      <style>
      body{font-family:Arial,sans-serif;padding:24px;color:#111}
      h1{font-size:20px;margin:0 0 12px}
      p{font-size:12px;color:#333}
      table{border-collapse:collapse;width:100%}
      th,td{border:1px solid #bbb;padding:8px;font-size:12px;text-align:left}
      th{background:#ece8ff}
      </style></head><body>
      <h1>Lynx Diploma Compare Report</h1>
      <p>Runs: ${rows.length}. Generated: ${new Date().toLocaleString()}</p>
      <table><thead><tr><th>Label</th><th>Status</th><th>Lang</th><th>Vuln</th><th>Tests</th><th>Elapsed(s)</th></tr></thead><tbody>${htmlRows}</tbody></table>
      </body></html>`;
    const w = window.open('', '_blank');
    if (!w) return;
    w.document.write(html);
    w.document.close();
    w.focus();
    w.print();
  };

  const columns: GridColDef[] = [
    { field: 'label', headerName: 'Прогон', minWidth: 220, flex: 1, valueGetter: (p) => p.row.label ?? p.row.id },
    { field: 'status', headerName: 'Статус', minWidth: 110 },
    { field: 'language', headerName: 'Язык', minWidth: 100 },
    { field: 'strict_offline', headerName: 'Strict', minWidth: 90, valueGetter: (p) => (p.value ? 'yes' : 'no') },
    { field: 'vulnerabilities_total', headerName: 'Vuln', type: 'number', minWidth: 90 },
    { field: 'tests_exit_code', headerName: 'Tests', type: 'number', minWidth: 90 },
    { field: 'exit_code', headerName: 'Exit', type: 'number', minWidth: 90 },
    { field: 'elapsed_seconds', headerName: 'Elapsed(s)', type: 'number', minWidth: 120 },
    {
      field: 'created_at',
      headerName: 'Создан',
      minWidth: 180,
      valueGetter: (p) => (p.value ? new Date(String(p.value)).toLocaleString() : '—'),
    },
  ];

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
        Сравнение версий алгоритма
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        Динамика уязвимостей, времени и статуса тестов по прогонам.
      </Typography>

      <Paper sx={{ p: 2.5, borderRadius: 2, mb: 3 }}>
        <Stack direction={{ xs: 'column', md: 'row' }} spacing={1}>
          <TextField select size="small" label="Сортировка" value={sortBy} onChange={(e) => setSortBy(e.target.value)}>
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
          >
            <MenuItem value="desc">По убыв.</MenuItem>
            <MenuItem value="asc">По возр.</MenuItem>
          </TextField>
          <Button variant="outlined" onClick={() => void load()}>
            Обновить
          </Button>
          <Button variant="outlined" onClick={exportDiplomaJson}>
            Экспорт общего JSON
          </Button>
          <Button variant="contained" onClick={exportDiplomaPdf}>
            Экспорт общего PDF
          </Button>
        </Stack>
      </Paper>

      <Paper sx={{ p: 2.5, borderRadius: 2, mb: 3 }}>
        <Typography variant="h6" sx={{ mb: 1.5 }}>
          Графики динамики
        </Typography>
        <Box sx={{ width: '100%', height: 360 }}>
          <ResponsiveContainer>
            <LineChart data={timelineData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="idx" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="vulnerabilities_total" name="Vulnerabilities" stroke="#8b5cf6" />
              <Line type="monotone" dataKey="elapsed_seconds" name="Elapsed(s)" stroke="#06b6d4" />
              <Line type="monotone" dataKey="tests_exit_code" name="Tests exit" stroke="#f43f5e" />
            </LineChart>
          </ResponsiveContainer>
        </Box>
      </Paper>

      <Paper
        sx={{
          p: 2.5,
          borderRadius: 2,
          background: (t) => `linear-gradient(180deg, ${t.palette.background.paper} 0%, ${t.palette.action.hover} 100%)`,
        }}
      >
        <Typography variant="h6" sx={{ mb: 1.5 }}>
          Таблица сравнений
        </Typography>
        <DataGrid
          rows={rows}
          columns={columns}
          autoHeight
          disableRowSelectionOnClick
          pageSizeOptions={[10, 25, 50, 100]}
          initialState={{ pagination: { paginationModel: { pageSize: 10, page: 0 } } }}
        />
      </Paper>
    </Box>
  );
};
