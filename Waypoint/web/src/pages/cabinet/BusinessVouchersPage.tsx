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
  createVoucher,
  deleteVoucher,
  listVouchers,
  patchVoucher,
  type VoucherDto,
} from '../../services/cabinet.service';
import { useNotification } from '../../app/hooks/useNotification';

const emptyForm = { code: '', campaign: '', redeem_limit: '100', redeemed: '0' };

export const BusinessVouchersPage: React.FC = () => {
  const { showError, showSuccess } = useNotification();
  const [rows, setRows] = useState<VoucherDto[]>([]);
  const [loading, setLoading] = useState(true);
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<VoucherDto | null>(null);
  const [form, setForm] = useState(emptyForm);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setRows(await listVouchers());
    } catch {
      showError('Не удалось загрузить ваучеры');
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

  const openEdit = (v: VoucherDto) => {
    setEditing(v);
    setForm({
      code: v.code,
      campaign: v.campaign,
      redeem_limit: String(v.redeem_limit),
      redeemed: String(v.redeemed),
    });
    setOpen(true);
  };

  const save = async () => {
    const redeem_limit = parseInt(form.redeem_limit, 10);
    const redeemed = parseInt(form.redeemed, 10);
    if (!Number.isFinite(redeem_limit) || redeem_limit < 0 || !Number.isFinite(redeemed) || redeemed < 0) {
      showError('Лимит и погашения должны быть неотрицательными числами');
      return;
    }
    try {
      if (editing) {
        await patchVoucher(editing.id, {
          code: form.code.trim(),
          campaign: form.campaign.trim(),
          redeem_limit,
          redeemed,
        });
        showSuccess('Сохранено');
      } else {
        await createVoucher({
          code: form.code.trim(),
          campaign: form.campaign.trim(),
          redeem_limit,
          redeemed,
        });
        showSuccess('Создано');
      }
      setOpen(false);
      void load();
    } catch {
      showError('Ошибка сохранения (код должен быть уникальным)');
    }
  };

  const remove = async (id: string) => {
    if (!window.confirm('Удалить ваучер?')) return;
    try {
      await deleteVoucher(id);
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
          Ваучеры и промокоды
        </Typography>
        <Button variant="contained" startIcon={<Add />} onClick={openCreate}>
          Новый код
        </Button>
      </Stack>
      <Typography variant="body1" color="text.secondary" sx={{ maxWidth: 800, lineHeight: 1.65 }}>
        Данные хранятся в PostgreSQL на сервере (таблица <code>waypoint_vouchers</code>), привязка к вашему аккаунту.
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
                <TableCell>Код</TableCell>
                <TableCell>Кампания</TableCell>
                <TableCell align="right">Погашено</TableCell>
                <TableCell align="right">Лимит</TableCell>
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
                      Пока нет записей — создайте промокод.
                    </Typography>
                  </TableCell>
                </TableRow>
              )}
              {rows.map((r) => (
                <TableRow key={r.id}>
                  <TableCell>{r.code}</TableCell>
                  <TableCell>{r.campaign || '—'}</TableCell>
                  <TableCell align="right">{r.redeemed}</TableCell>
                  <TableCell align="right">{r.redeem_limit}</TableCell>
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
        feature="vouchers_bulk"
        title="Массовые операции Pro"
        description="Импорт CSV и выгрузка отчётов по ваучерам."
      >
        <Typography variant="body2" color="text.secondary">
          На Pro можно добавить импорт/экспорт — пока заглушка.
        </Typography>
      </FeatureGate>

      <Dialog open={open} onClose={() => setOpen(false)} fullWidth maxWidth="xs">
        <DialogTitle>{editing ? 'Изменить ваучер' : 'Новый ваучер'}</DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, pt: 1 }}>
          <TextField
            label="Код"
            value={form.code}
            onChange={(e) => setForm((f) => ({ ...f, code: e.target.value }))}
            fullWidth
            required
            inputProps={{ style: { textTransform: 'uppercase' } }}
          />
          <TextField
            label="Кампания"
            value={form.campaign}
            onChange={(e) => setForm((f) => ({ ...f, campaign: e.target.value }))}
            fullWidth
          />
          <TextField
            label="Лимит погашений"
            type="number"
            value={form.redeem_limit}
            onChange={(e) => setForm((f) => ({ ...f, redeem_limit: e.target.value }))}
            fullWidth
          />
          <TextField
            label="Уже погашено"
            type="number"
            value={form.redeemed}
            onChange={(e) => setForm((f) => ({ ...f, redeemed: e.target.value }))}
            fullWidth
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpen(false)}>Отмена</Button>
          <Button variant="contained" onClick={() => void save()} disabled={!form.code.trim()}>
            Сохранить
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
};
