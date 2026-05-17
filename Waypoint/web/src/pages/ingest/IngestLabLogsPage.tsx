import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Chip,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { Refresh } from '@mui/icons-material';
import { Link as RouterLink } from 'react-router-dom';
import { fetchMyIngestLogs, type IngestLogRow } from '../../services/ingest.service';

export const IngestLabLogsPage: React.FC = () => {
  const [rows, setRows] = useState<IngestLogRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchMyIngestLogs();
      setRows(data);
    } catch {
      setError('Не удалось загрузить логи. Убедитесь, что waypoint-api запущен.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <Box>
      <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
        Журнал ingest-логов
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Последние 200 строк по вашим API-ключам. Чтобы появились записи —{' '}
        <RouterLink to="/dashboard/ingest-lab/send">отправьте тестовый набор</RouterLink>.
      </Typography>

      <Button startIcon={<Refresh />} onClick={() => void load()} disabled={loading} sx={{ mb: 2 }}>
        Обновить
      </Button>

      {error && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}

      <Paper sx={{ overflow: 'auto' }}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Время</TableCell>
              <TableCell>Уровень</TableCell>
              <TableCell>Сообщение</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((r, i) => (
              <TableRow key={`${r.timestamp}-${i}`}>
                <TableCell sx={{ whiteSpace: 'nowrap' }}>
                  {r.timestamp ? new Date(r.timestamp).toLocaleString() : '—'}
                </TableCell>
                <TableCell>
                  <Chip
                    size="small"
                    label={r.level}
                    color={r.level === 'error' ? 'error' : r.level === 'warn' ? 'warning' : 'default'}
                  />
                </TableCell>
                <TableCell>{r.message}</TableCell>
              </TableRow>
            ))}
            {!loading && rows.length === 0 && (
              <TableRow>
                <TableCell colSpan={3}>
                  Пока нет логов. Отправьте демо из раздела «Запись в облако».
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </Paper>
    </Box>
  );
};
