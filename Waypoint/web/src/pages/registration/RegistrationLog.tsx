import React, { useEffect, useState } from 'react';
import {
  Box,
  Typography,
  Paper,
  Alert,
  CircularProgress,
} from '@mui/material';
import { DataGrid, GridColDef } from '@mui/x-data-grid';
import api from '../../services/api';

interface Row {
  id: string;
  user_id: string;
  email: string;
  nickname: string;
  created_at: string;
}

export const RegistrationLog: React.FC = () => {
  const [rows, setRows] = useState<Row[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    (async () => {
      try {
        const { data } = await api.get<Row[]>('/admin/registration-log');
        setRows(
          data.map((r) => ({
            ...r,
            id: r.id,
          })),
        );
      } catch (e: unknown) {
        const err = e as { response?: { data?: { error?: string } } };
        setError(err.response?.data?.error || 'Не удалось загрузить журнал');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const columns: GridColDef[] = [
    { field: 'created_at', headerName: 'Время', flex: 1, minWidth: 180 },
    { field: 'email', headerName: 'Email', flex: 1, minWidth: 200 },
    { field: 'nickname', headerName: 'Ник', flex: 0.8, minWidth: 120 },
    { field: 'user_id', headerName: 'User ID', flex: 1, minWidth: 280 },
  ];

  if (loading) {
    return (
      <Box display="flex" justifyContent="center" p={4}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box p={2}>
      <Typography variant="h5" gutterBottom>
        Журнал регистраций
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Записи создаются при каждой успешной регистрации; пользователю выдаётся API-ключ для ingest.
      </Typography>
      {error && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {error}
        </Alert>
      )}
      <Paper sx={{ height: 560, width: '100%' }}>
        <DataGrid rows={rows} columns={columns} pageSizeOptions={[25, 50]} disableRowSelectionOnClick />
      </Paper>
    </Box>
  );
};
