import React, { useEffect, useState } from 'react';
import { Alert, Box, Paper, Table, TableBody, TableCell, TableHead, TableRow, Typography } from '@mui/material';
import api from '../../services/api';

type Host = {
  id: string;
  device_name: string;
  host_label?: string;
  os_info?: string;
  sync_telemetry: boolean;
  last_seen_at?: string;
};

export const DesktopHostsPage: React.FC = () => {
  const [hosts, setHosts] = useState<Host[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    api
      .get<Host[]>('/me/desktop/hosts')
      .then((r) => setHosts(r.data))
      .catch(() => setError('Не удалось загрузить хосты Desktop'));
  }, []);

  return (
    <Box>
      <Typography variant="h5" gutterBottom>
        Desktop hosts
      </Typography>
      <Typography color="text.secondary" sx={{ mb: 2 }}>
        Машины команды с установленным Waypoint Desktop и активным API-ключом.
      </Typography>
      {error && <Alert severity="warning">{error}</Alert>}
      <Paper>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Устройство</TableCell>
              <TableCell>Хост</TableCell>
              <TableCell>ОС</TableCell>
              <TableCell>Телеметрия</TableCell>
              <TableCell>Last seen</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {hosts.map((h) => (
              <TableRow key={h.id}>
                <TableCell>{h.device_name}</TableCell>
                <TableCell>{h.host_label ?? '—'}</TableCell>
                <TableCell>{h.os_info ?? '—'}</TableCell>
                <TableCell>{h.sync_telemetry ? 'да' : 'нет'}</TableCell>
                <TableCell>{h.last_seen_at ? new Date(h.last_seen_at).toLocaleString() : '—'}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </Paper>
    </Box>
  );
};
