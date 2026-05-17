import React, { useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Chip,
  MenuItem,
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
import { ContentCopy } from '@mui/icons-material';
import api from '../../services/api';
import { useNotification } from '../../app/hooks/useNotification';

type KeyRow = {
  id: string;
  key_prefix: string;
  note?: string | null;
  created_by?: string | null;
  created_at: string;
  expires_at?: string | null;
  used_at?: string | null;
  revoked_at?: string | null;
  used_by_email?: string | null;
  key_kind?: string;
  pool_generated?: boolean;
};

type CreateResp = {
  id: string;
  key: string;
  key_prefix: string;
  created_at: string;
  expires_at?: string | null;
};

export const AdminKeys: React.FC = () => {
  const { showError, showSuccess } = useNotification();
  const [rows, setRows] = useState<KeyRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [note, setNote] = useState('');
  const [days, setDays] = useState('30');
  const [keyKind, setKeyKind] = useState<'admin' | 'nexus'>('admin');
  const [createdKey, setCreatedKey] = useState<string | null>(null);

  const load = async () => {
    setLoading(true);
    try {
      const { data } = await api.get<KeyRow[]>('/admin/keys');
      setRows(data);
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? String((e as { response?: { data?: { error?: string } } }).response?.data?.error ?? 'Ошибка')
          : 'Не удалось загрузить ключи';
      showError(msg);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void load();
  }, []);

  const createKey = async () => {
    setLoading(true);
    try {
      const expires = Number(days);
      const { data } = await api.post<CreateResp>('/admin/keys', {
        note: note.trim() || null,
        expires_in_days: Number.isFinite(expires) && expires > 0 ? expires : null,
        key_kind: keyKind,
      });
      setCreatedKey(data.key);
      setNote('');
      showSuccess('Ключ создан. Скопируйте его сейчас: повторно он не отображается.');
      await load();
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? String((e as { response?: { data?: { error?: string } } }).response?.data?.error ?? 'Ошибка')
          : 'Не удалось создать ключ';
      showError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
        Ключи активации admin
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        Пул admin-ключей пополняется автоматически на сервере (до 20 свободных). Здесь можно вручную создать ключ admin или
        Lynx (ядро движка).
      </Typography>

      <Paper sx={{ p: 2.5, borderRadius: 3, mb: 2 }}>
        <Stack direction={{ xs: 'column', md: 'row' }} spacing={1.5}>
          <TextField
            fullWidth
            label="Комментарий (кому/зачем)"
            value={note}
            onChange={(e) => setNote(e.target.value)}
          />
          <TextField
            select
            label="Тип ключа"
            value={keyKind}
            onChange={(e) => setKeyKind(e.target.value as 'admin' | 'nexus')}
            sx={{ minWidth: 160 }}
          >
            <MenuItem value="admin">admin</MenuItem>
            <MenuItem value="nexus">Lynx (платформа, в API: nexus)</MenuItem>
          </TextField>
          <TextField
            label="Дней до истечения"
            type="number"
            value={days}
            onChange={(e) => setDays(e.target.value)}
            sx={{ minWidth: 180 }}
          />
          <Button variant="contained" onClick={() => void createKey()} disabled={loading}>
            Создать ключ
          </Button>
        </Stack>
      </Paper>

      {createdKey && (
        <Alert
          severity="success"
          sx={{ mb: 2 }}
          action={
            <Button
              size="small"
              startIcon={<ContentCopy />}
              onClick={async () => {
                await navigator.clipboard.writeText(createdKey);
                showSuccess('Ключ скопирован');
              }}
            >
              Копировать
            </Button>
          }
        >
          <Typography variant="body2" sx={{ wordBreak: 'break-all' }}>
            {createdKey}
          </Typography>
        </Alert>
      )}

      <Paper sx={{ borderRadius: 3, overflow: 'hidden' }}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Префикс</TableCell>
              <TableCell>Тип</TableCell>
              <TableCell>Пул</TableCell>
              <TableCell>Комментарий</TableCell>
              <TableCell>Создан</TableCell>
              <TableCell>Истекает</TableCell>
              <TableCell>Статус</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((r) => {
              const status = r.revoked_at
                ? 'revoked'
                : r.used_at
                  ? `used (${r.used_by_email ?? 'unknown'})`
                  : 'active';
              return (
                <TableRow key={r.id}>
                  <TableCell sx={{ fontFamily: 'monospace' }}>{r.key_prefix}********</TableCell>
                  <TableCell>{r.key_kind ?? 'admin'}</TableCell>
                  <TableCell>{r.pool_generated ? 'да' : 'нет'}</TableCell>
                  <TableCell>{r.note || '—'}</TableCell>
                  <TableCell>{new Date(r.created_at).toLocaleString()}</TableCell>
                  <TableCell>{r.expires_at ? new Date(r.expires_at).toLocaleString() : 'без срока'}</TableCell>
                  <TableCell>
                    <Chip
                      size="small"
                      label={status}
                      color={status.startsWith('active') ? 'success' : status.startsWith('used') ? 'default' : 'warning'}
                    />
                  </TableCell>
                </TableRow>
              );
            })}
            {rows.length === 0 && !loading && (
              <TableRow>
                <TableCell colSpan={7} align="center">
                  Нет ключей
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
      </Paper>
    </Box>
  );
};
