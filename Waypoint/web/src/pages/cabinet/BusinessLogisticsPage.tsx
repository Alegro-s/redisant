import React, { useCallback, useEffect, useState } from 'react';
import {
  Stack,
  Typography,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Button,
  TextField,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Box,
  CircularProgress,
} from '@mui/material';
import { Add, Delete, Edit } from '@mui/icons-material';
import { FeatureGate } from '../../components/common/FeatureGate';
import {
  createShipment,
  deleteShipment,
  listShipments,
  patchShipment,
  type ShipmentDto,
} from '../../services/cabinet.service';
import { useNotification } from '../../app/hooks/useNotification';

const emptyForm = { external_ref: '', route: '', status: 'draft', carrier: '' };

export const BusinessLogisticsPage: React.FC = () => {
  const { showError, showSuccess } = useNotification();
  const [rows, setRows] = useState<ShipmentDto[]>([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<ShipmentDto | null>(null);
  const [form, setForm] = useState(emptyForm);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setRows(await listShipments());
    } catch {
      showError('Не удалось загрузить отправления');
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [showError]);

  useEffect(() => {
    void load();
  }, [load]);

  const openCreate = () => {
    setEditing(null);
    setForm(emptyForm);
    setOpen(true);
  };

  const openEdit = (s: ShipmentDto) => {
    setEditing(s);
    setForm({
      external_ref: s.external_ref,
      route: s.route,
      status: s.status,
      carrier: s.carrier,
    });
    setOpen(true);
  };

  const save = async () => {
    try {
      if (editing) {
        await patchShipment(editing.id, {
          external_ref: form.external_ref.trim(),
          route: form.route.trim(),
          status: form.status.trim(),
          carrier: form.carrier.trim(),
        });
        showSuccess('Сохранено');
      } else {
        await createShipment({
          external_ref: form.external_ref.trim(),
          route: form.route.trim(),
          status: form.status.trim(),
          carrier: form.carrier.trim(),
        });
        showSuccess('Создано');
      }
      setOpen(false);
      void load();
    } catch {
      showError('Ошибка сохранения');
    }
  };

  const remove = async (id: string) => {
    if (!window.confirm('Удалить отправление?')) return;
    try {
      await deleteShipment(id);
      showSuccess('Удалено');
      void load();
    } catch {
      showError('Не удалось удалить');
    }
  };

  return (
    <Stack spacing={2.5}>
      <Stack direction={{ xs: 'column', sm: 'row' }} justifyContent="space-between" alignItems={{ sm: 'center' }} gap={1}>
        <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.02em' }}>
          Логистика
        </Typography>
        <Button variant="contained" startIcon={<Add />} onClick={openCreate}>
          Новое отправление
        </Button>
      </Stack>
      <Typography variant="body1" color="text.secondary" sx={{ maxWidth: 800, lineHeight: 1.65 }}>
        Отправления в БД (<code>waypoint_shipments</code>). Связывайте с ingest и вебхуками на стороне Pro.
      </Typography>

      {loading ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
          <CircularProgress />
        </Box>
      ) : (
        <TableContainer component={Paper} variant="outlined" sx={{ borderRadius: 2 }}>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Внешний №</TableCell>
                <TableCell>Маршрут</TableCell>
                <TableCell>Статус</TableCell>
                <TableCell>Перевозчик</TableCell>
                <TableCell align="right" width={100}>
                  Действия
                </TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {rows.length === 0 && (
                <TableRow>
                  <TableCell colSpan={5}>
                    <Typography variant="body2" color="text.secondary">
                      Нет отправлений — добавьте первую строку.
                    </Typography>
                  </TableCell>
                </TableRow>
              )}
              {rows.map((r) => (
                <TableRow key={r.id}>
                  <TableCell>{r.external_ref || r.id.slice(0, 8)}</TableCell>
                  <TableCell>{r.route || '—'}</TableCell>
                  <TableCell>{r.status}</TableCell>
                  <TableCell>{r.carrier || '—'}</TableCell>
                  <TableCell align="right">
                    <IconButton size="small" onClick={() => openEdit(r)} aria-label="Изменить">
                      <Edit fontSize="small" />
                    </IconButton>
                    <IconButton size="small" onClick={() => void remove(r.id)} aria-label="Удалить">
                      <Delete fontSize="small" />
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <FeatureGate
        feature="logistics_webhooks"
        title="Вебхуки и интеграции Pro"
        description="Подписка на статусы перевозчика и автоматическая запись в эту таблицу."
      >
        <Typography variant="body2" color="text.secondary">
          Настройте endpoint в разделе подключения (Pro).
        </Typography>
      </FeatureGate>

      <Dialog open={open} onClose={() => setOpen(false)} fullWidth maxWidth="sm">
        <DialogTitle>{editing ? 'Изменить отправление' : 'Новое отправление'}</DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
          <TextField
            label="Внешний номер / трек"
            value={form.external_ref}
            onChange={(e) => setForm((f) => ({ ...f, external_ref: e.target.value }))}
            fullWidth
          />
          <TextField
            label="Маршрут"
            value={form.route}
            onChange={(e) => setForm((f) => ({ ...f, route: e.target.value }))}
            fullWidth
            placeholder="МСК → СПб"
          />
          <TextField
            label="Статус"
            value={form.status}
            onChange={(e) => setForm((f) => ({ ...f, status: e.target.value }))}
            fullWidth
          />
          <TextField
            label="Перевозчик"
            value={form.carrier}
            onChange={(e) => setForm((f) => ({ ...f, carrier: e.target.value }))}
            fullWidth
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpen(false)}>Отмена</Button>
          <Button variant="contained" onClick={() => void save()}>
            Сохранить
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
};
