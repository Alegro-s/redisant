import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import api from '../../services/api';
import type { MetricRow } from './ingestLabShared';

export const IngestLabMetricsPage: React.FC = () => {
  const [metrics, setMetrics] = useState<MetricRow[]>([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

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

  useEffect(() => {
    void loadMetrics();
  }, [loadMetrics]);

  return (
    <>
      {error && (
        <Alert severity="warning" sx={{ mb: 2 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}
      <Paper>
        <Box p={2} display="flex" justifyContent="space-between" alignItems="center">
          <Typography variant="subtitle1">GET /me/metrics (последние точки)</Typography>
          <Button variant="outlined" onClick={() => void loadMetrics()} disabled={loading}>
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
    </>
  );
};
