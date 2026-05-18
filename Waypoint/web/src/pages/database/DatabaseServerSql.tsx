import React, { useState } from 'react';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  FormControlLabel,
  Paper,
  Switch,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { PlayArrow as RunIcon } from '@mui/icons-material';
import api from '../../services/api';
import { useAuth } from '../../app/contexts/AuthContext';
import { useNotification } from '../../app/hooks/useNotification';

export const DatabaseServerSql: React.FC = () => {
  const { isAdmin } = useAuth();
  const [query, setQuery] = useState('SELECT current_timestamp AS server_time;');
  const [result, setResult] = useState<Record<string, unknown>[] | null>(null);
  const [columns, setColumns] = useState<string[]>([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [readOnly, setReadOnly] = useState(true);
  const { showSuccess, showError: toastError } = useNotification();

  const handleRun = async () => {
    if (!query.trim()) return;
    setError('');
    setLoading(true);
    const url = isAdmin ? '/admin/db/query' : '/me/db/query';
    const payload = isAdmin ? { query: query.trim(), read_only: readOnly } : { query: query.trim(), read_only: true };
    try {
      const response = await api.post(url, payload);
      if (response.data.rows) {
        setResult(response.data.rows);
        setColumns(response.data.columns || []);
        showSuccess(`${response.data.rows.length} строк`);
      } else {
        setResult(null);
        setColumns([]);
        showSuccess('Запрос выполнен');
      }
    } catch (err: unknown) {
      const ax = err as { response?: { data?: { error?: string } } };
      const msg = ax.response?.data?.error || 'Ошибка выполнения';
      setError(msg);
      toastError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Paper sx={{ p: 2, borderRadius: 2 }}>
      {isAdmin ? (
        <FormControlLabel
          control={<Switch checked={readOnly} onChange={(e) => setReadOnly(e.target.checked)} />}
          label="Только чтение (SELECT)"
          sx={{ mb: 1 }}
        />
      ) : (
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1 }}>
          Режим пользователя: только SELECT
        </Typography>
      )}
      <TextField
        label="SQL"
        multiline
        rows={6}
        fullWidth
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        sx={{ mb: 2, fontFamily: 'monospace' }}
      />
      <Button
        variant="contained"
        startIcon={loading ? <CircularProgress size={20} /> : <RunIcon />}
        disabled={loading}
        onClick={() => void handleRun()}
      >
        Выполнить
      </Button>
      {error && (
        <Alert severity="error" sx={{ mt: 2 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}
      {result && result.length > 0 && (
        <TableContainer sx={{ mt: 2, maxHeight: 360 }}>
          <Table size="small" stickyHeader>
            <TableHead>
              <TableRow>
                {columns.map((col) => (
                  <TableCell key={col}>{col}</TableCell>
                ))}
              </TableRow>
            </TableHead>
            <TableBody>
              {result.map((row, idx) => (
                <TableRow key={idx}>
                  {columns.map((col) => (
                    <TableCell key={col}>{row[col] != null ? String(row[col]) : 'NULL'}</TableCell>
                  ))}
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}
    </Paper>
  );
};
