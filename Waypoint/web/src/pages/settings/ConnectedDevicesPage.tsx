import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
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
import api from '../../services/api';
import authApi from '../../services/authApi';

type Device = {
  id: string;
  device_id: string;
  device_name: string;
  host_label?: string;
  os_info?: string;
  sync_telemetry: boolean;
  sync_tasks: boolean;
  sync_projects: boolean;
  last_seen_at?: string;
};

export const ConnectedDevicesPage: React.FC = () => {
  const [devices, setDevices] = useState<Device[]>([]);
  const [pairCode, setPairCode] = useState<string | null>(null);
  const [confirmCode, setConfirmCode] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const load = useCallback(async () => {
    const { data } = await api.get<Device[]>('/me/desktop/devices');
    setDevices(data);
  }, []);

  useEffect(() => {
    load().catch(() => setError('Не удалось загрузить устройства'));
  }, [load]);

  const startPair = async () => {
    setError('');
    setLoading(true);
    try {
      const { data } = await authApi.post<{ code: string; expires_at: string }>('/auth/desktop/pair/start');
      setPairCode(data.code);
    } catch {
      setError('Ошибка создания кода');
    } finally {
      setLoading(false);
    }
  };

  const confirmPair = async () => {
    try {
      await authApi.post('/auth/desktop/pair/confirm', { code: confirmCode.trim().toUpperCase() });
      setConfirmCode('');
      setError('');
    } catch {
      setError('Неверный или просроченный код');
    }
  };

  const revoke = async (id: string) => {
    await api.delete(`/me/desktop/devices/${id}`);
    await load();
  };

  return (
    <Box>
      <Typography variant="h5" gutterBottom>
        Подключённые устройства (Waypoint Desktop)
      </Typography>
      <Typography color="text.secondary" sx={{ mb: 2 }}>
        Создайте код привязки WD-XXXXXXXX и введите его в приложении Desktop.
      </Typography>
      {error && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}
      <Paper sx={{ p: 2, mb: 3 }}>
        <Stack direction="row" gap={2} flexWrap="wrap" alignItems="center">
          <Button variant="contained" onClick={startPair} disabled={loading}>
            Создать код привязки
          </Button>
          {pairCode && (
            <Typography variant="h6" sx={{ fontFamily: 'monospace', color: 'primary.main' }}>
              {pairCode}
            </Typography>
          )}
        </Stack>
        <Stack direction="row" gap={1} sx={{ mt: 2 }}>
          <TextField
            size="small"
            label="Подтвердить код с Desktop"
            value={confirmCode}
            onChange={(e) => setConfirmCode(e.target.value)}
          />
          <Button variant="outlined" onClick={confirmPair}>
            Подтвердить
          </Button>
        </Stack>
      </Paper>
      <Table size="small">
        <TableHead>
          <TableRow>
            <TableCell>Имя</TableCell>
            <TableCell>Хост</TableCell>
            <TableCell>ОС</TableCell>
            <TableCell>Последний раз</TableCell>
            <TableCell />
          </TableRow>
        </TableHead>
        <TableBody>
          {devices.map((d) => (
            <TableRow key={d.id}>
              <TableCell>{d.device_name}</TableCell>
              <TableCell>{d.host_label ?? '—'}</TableCell>
              <TableCell>{d.os_info ?? '—'}</TableCell>
              <TableCell>{d.last_seen_at ? new Date(d.last_seen_at).toLocaleString() : '—'}</TableCell>
              <TableCell>
                <Button size="small" color="error" onClick={() => revoke(d.id)}>
                  Отозвать
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </Box>
  );
};
