import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Chip,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import api from '../../services/api';
import type { MetricsSummary } from './ingestLabShared';

export const IngestLabSummaryPage: React.FC = () => {
  const [summary, setSummary] = useState<MetricsSummary | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const loadSummary = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const { data } = await api.get<MetricsSummary>('/me/metrics/summary');
      setSummary(data);
    } catch (e: unknown) {
      const err = e as { response?: { data?: { error?: string } } };
      setError(err.response?.data?.error || 'Сводка пока недоступна. Завершите настройку или создайте ключ.');
      setSummary(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadSummary();
  }, [loadSummary]);

  return (
    <>
      {error && (
        <Alert severity="warning" sx={{ mb: 2 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}
      <Paper sx={{ p: 2 }}>
        <Box display="flex" justifyContent="space-between" alignItems="center" mb={2}>
          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
            Сводка событий
          </Typography>
          <Button variant="outlined" onClick={() => void loadSummary()} disabled={loading}>
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
            <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.55 }}>
              Последние значения по каждому показателю — те же цифры, что на странице «Сводка».
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
    </>
  );
};
