import React, { useCallback, useEffect, useState } from 'react';
import {
  Box,
  Button,
  Paper,
  Typography,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TableContainer,
  CircularProgress,
} from '@mui/material';
import api from '../../services/api';
import { useNotification } from '../../app/hooks/useNotification';
import { useAuth } from '../../app/contexts/AuthContext';

export const Billing: React.FC = () => {
  const { isAdmin } = useAuth();
  const { showError, showSuccess } = useNotification();
  const [loading, setLoading] = useState(false);
  const [account, setAccount] = useState<Record<string, unknown> | null>(null);
  const [ledger, setLedger] = useState<unknown[]>([]);
  const [summary, setSummary] = useState<unknown>(null);
  const [providers, setProviders] = useState<{ stripe?: boolean; yookassa?: boolean } | null>(null);

  const loadUser = useCallback(async () => {
    setLoading(true);
    try {
      const r = await api.get('/me/billing');
      setAccount((r.data?.account as Record<string, unknown>) ?? null);
      setLedger(Array.isArray(r.data?.ledger) ? r.data.ledger : []);
      const cp = r.data?.checkout_providers as { stripe?: boolean; yookassa?: boolean } | undefined;
      setProviders(cp ?? null);
    } catch {
      showError('Не удалось загрузить биллинг');
    } finally {
      setLoading(false);
    }
  }, [showError]);

  const loadAdmin = useCallback(async () => {
    if (!isAdmin) return;
    try {
      const r = await api.get('/admin/billing/summary');
      setSummary(r.data ?? null);
    } catch {
      showError('Не удалось загрузить сводку биллинга');
    }
  }, [isAdmin, showError]);

  useEffect(() => {
    void loadUser();
    void loadAdmin();
  }, [loadUser, loadAdmin]);

  const demoCheckout = async () => {
    try {
      const r = await api.post('/me/billing/checkout', { plan: 'pro' });
      const url = r.data?.checkout_url as string | undefined;
      if (url && /^https?:\/\//i.test(url)) {
        window.open(url, '_blank', 'noopener,noreferrer');
        showSuccess('Открыта страница оплаты');
        return;
      }
      showSuccess(
        (r.data?.message as string) || 'Запрос отправлен — при демо режиме оплата не списывается',
      );
    } catch {
      showError('Checkout недоступен');
    }
  };

  const checkoutStripe = async () => {
    try {
      const r = await api.post('/me/billing/checkout', { plan: 'pro', provider: 'stripe' });
      const url = r.data?.checkout_url as string | undefined;
      if (url && /^https?:\/\//i.test(url)) {
        window.open(url, '_blank', 'noopener,noreferrer');
        showSuccess('Stripe Checkout');
        void loadUser();
        return;
      }
      showSuccess((r.data?.message as string) || 'Нет редиректа');
    } catch {
      showError('Stripe checkout ошибка');
    }
  };

  const checkoutYookassa = async () => {
    try {
      const r = await api.post('/me/billing/checkout', { plan: 'pro', provider: 'yookassa' });
      const url = r.data?.checkout_url as string | undefined;
      if (url && /^https?:\/\//i.test(url)) {
        window.open(url, '_blank', 'noopener,noreferrer');
        showSuccess('ЮKassa');
        void loadUser();
        return;
      }
      showSuccess((r.data?.message as string) || 'Нет редиректа');
    } catch {
      showError('ЮKassa ошибка');
    }
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 2 }}>
        Биллинг
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        Stripe: <code>STRIPE_SECRET_KEY</code>, Price ID (<code>STRIPE_PRICE_PRO</code>…),{' '}
        <code>STRIPE_WEBHOOK_SECRET</code>, success/cancel URL. ЮKassa: <code>YOOKASSA_SHOP_ID</code>,{' '}
        <code>YOOKASSA_SECRET_KEY</code>, вебхук на <code>/integrations/billing/yookassa-webhook</code>.
      </Typography>

      {isAdmin && summary != null && (
        <Paper sx={{ p: 2, mb: 3, borderRadius: 2 }}>
          <Typography variant="h6" sx={{ mb: 1 }}>
            Сводка (admin)
          </Typography>
          <Box component="pre" sx={{ fontSize: 12, overflow: 'auto' }}>
            {JSON.stringify(summary, null, 2)}
          </Box>
        </Paper>
      )}

      <Paper sx={{ p: 3, borderRadius: 3, mb: 3 }}>
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2, mb: 2 }}>
          <Typography variant="h6">Текущий аккаунт</Typography>
          {loading ? <CircularProgress size={22} /> : null}
          <Button size="small" variant="outlined" disabled={loading} onClick={() => void loadUser()}>
            Обновить
          </Button>
          <Button size="small" variant="contained" onClick={() => void demoCheckout()}>
            Демо checkout (pro)
          </Button>
          {providers?.stripe ? (
            <Button size="small" variant="outlined" color="primary" onClick={() => void checkoutStripe()}>
              Stripe Pro
            </Button>
          ) : null}
          {providers?.yookassa ? (
            <Button size="small" variant="outlined" color="secondary" onClick={() => void checkoutYookassa()}>
              ЮKassa Pro
            </Button>
          ) : null}
        </Box>
        {providers && (
          <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1 }}>
            Провайдеры на сервере: Stripe={String(providers.stripe)} · ЮKassa={String(providers.yookassa)}
          </Typography>
        )}
        {account && (
          <Box component="pre" sx={{ bgcolor: 'action.hover', p: 2, borderRadius: 1, fontSize: 13 }}>
            {JSON.stringify(account, null, 2)}
          </Box>
        )}
      </Paper>

      <Paper sx={{ p: 3, borderRadius: 3 }}>
        <Typography variant="h6" sx={{ mb: 2 }}>
          Журнал (последние записи)
        </Typography>
        <TableContainer>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Вид</TableCell>
                <TableCell>Сумма (центы)</TableCell>
                <TableCell>Валюта</TableCell>
                <TableCell>Описание</TableCell>
                <TableCell>Дата</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {ledger.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5}>
                    <Typography variant="body2" color="text.secondary">
                      Пока пусто
                    </Typography>
                  </TableCell>
                </TableRow>
              ) : (
                ledger.map((row: unknown, i) => {
                  const e = row as Record<string, unknown>;
                  return (
                    <TableRow key={(e.id as string) || String(i)}>
                      <TableCell>{String(e.kind ?? '')}</TableCell>
                      <TableCell>{String(e.amount_cents ?? '')}</TableCell>
                      <TableCell>{String(e.currency ?? '')}</TableCell>
                      <TableCell>{String(e.description ?? '—')}</TableCell>
                      <TableCell>{String(e.created_at ?? '')}</TableCell>
                    </TableRow>
                  );
                })
              )}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>
    </Box>
  );
};
