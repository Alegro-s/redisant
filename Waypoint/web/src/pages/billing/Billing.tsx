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
  Grid,
  Card,
  CardContent,
  Chip,
  Stack,
} from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';
import api from '../../services/api';
import { useNotification } from '../../app/hooks/useNotification';
import { useAuth } from '../../app/contexts/AuthContext';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';

const PLANS = [
  {
    id: 'basic',
    title: 'Basic',
    price: 'Бесплатно',
    bullets: ['Метрики с лимитами', 'Привязка Desktop', 'Просмотр данных на сервере'],
  },
  {
    id: 'pro',
    title: 'Pro',
    price: 'По подписке',
    bullets: ['Больше метрик и хранилища', 'Свои таблицы и файлы', 'Приоритетная поддержка'],
  },
] as const;

export const Billing: React.FC = () => {
  const { isAdmin } = useAuth();
  const { workspace, saveWorkspace } = useWorkspace();
  const { showError, showSuccess } = useNotification();
  const [loading, setLoading] = useState(false);
  const [account, setAccount] = useState<Record<string, unknown> | null>(null);
  const [ledger, setLedger] = useState<unknown[]>([]);
  const [providers, setProviders] = useState<{ stripe?: boolean; yookassa?: boolean } | null>(null);

  const loadUser = useCallback(async () => {
    setLoading(true);
    try {
      const r = await api.get('/me/billing');
      setAccount((r.data?.account as Record<string, unknown>) ?? null);
      setLedger(Array.isArray(r.data?.ledger) ? r.data.ledger : []);
      setProviders((r.data?.checkout_providers as { stripe?: boolean; yookassa?: boolean }) ?? null);
    } catch {
      showError('Не удалось загрузить данные тарифа');
    } finally {
      setLoading(false);
    }
  }, [showError]);

  useEffect(() => {
    void loadUser();
  }, [loadUser]);

  const checkout = async (provider?: 'stripe' | 'yookassa') => {
    try {
      const r = await api.post('/me/billing/checkout', {
        plan: 'pro',
        ...(provider ? { provider } : {}),
      });
      const url = r.data?.checkout_url as string | undefined;
      if (url?.startsWith('http')) {
        window.open(url, '_blank', 'noopener,noreferrer');
        showSuccess('Открыта страница оплаты');
        return;
      }
      showSuccess((r.data?.message as string) || 'Запрос принят');
    } catch {
      showError('Оплата временно недоступна');
    }
  };

  const selectPlan = async (plan: 'basic' | 'pro') => {
    const ok = await saveWorkspace({ plan });
    if (ok) showSuccess(plan === 'pro' ? 'Выбран тариф Pro' : 'Выбран тариф Basic');
    else showError('Не удалось сохранить тариф');
  };

  const currentPlan = workspace.plan === 'pro' ? 'pro' : 'basic';

  return (
    <Box sx={{ maxWidth: 900, mx: 'auto' }}>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 0.5 }}>
        Тариф и оплата
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3, lineHeight: 1.6 }}>
        Выберите план для облака Waypoint Metric. Приложение на ПК скачивается отдельно.
      </Typography>

      <Grid container spacing={2} sx={{ mb: 3 }}>
        {PLANS.map((p) => {
          const active = currentPlan === p.id;
          return (
            <Grid item xs={12} md={6} key={p.id}>
              <Card
                variant="outlined"
                sx={{
                  height: '100%',
                  borderColor: active ? 'primary.main' : 'divider',
                  borderWidth: active ? 2 : 1,
                }}
              >
                <CardContent>
                  <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 1 }}>
                    <Typography variant="h6" sx={{ fontWeight: 700 }}>
                      {p.title}
                    </Typography>
                    {active ? <Chip size="small" color="primary" label="Текущий" /> : null}
                  </Stack>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    {p.price}
                  </Typography>
                  <Box component="ul" sx={{ m: 0, pl: 2.5, mb: 2 }}>
                    {p.bullets.map((b) => (
                      <Typography component="li" variant="body2" key={b} sx={{ mb: 0.5 }}>
                        {b}
                      </Typography>
                    ))}
                  </Box>
                  {p.id === 'basic' ? (
                    <Button variant={active ? 'outlined' : 'contained'} disabled={active} onClick={() => void selectPlan('basic')}>
                      Выбрать Basic
                    </Button>
                  ) : (
                    <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                      <Button variant="contained" onClick={() => void checkout()}>
                        Оформить Pro
                      </Button>
                      {providers?.stripe ? (
                        <Button variant="outlined" size="small" onClick={() => void checkout('stripe')}>
                          Stripe
                        </Button>
                      ) : null}
                      {providers?.yookassa ? (
                        <Button variant="outlined" size="small" onClick={() => void checkout('yookassa')}>
                          ЮKassa
                        </Button>
                      ) : null}
                    </Stack>
                  )}
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>

      <Paper sx={{ p: 2, borderRadius: 2, mb: 2 }}>
        <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
            Аккаунт
          </Typography>
          {loading ? <CircularProgress size={18} /> : null}
          <Button size="small" onClick={() => void loadUser()}>
            Обновить
          </Button>
        </Stack>
        {account ? (
          <Typography variant="body2" color="text.secondary">
            Статус: {String(account.status ?? '—')} · план в workspace: <strong>{currentPlan}</strong>
          </Typography>
        ) : (
          <Typography variant="body2" color="text.secondary">
            Нет данных биллинга
          </Typography>
        )}
        <Button component={RouterLink} to="/workspace/setup" size="small" sx={{ mt: 1 }}>
          Настройка сервера
        </Button>
      </Paper>

      {isAdmin && account && (
        <Paper sx={{ p: 2, mb: 2, borderRadius: 2 }}>
          <Typography variant="caption" color="text.secondary">
            Admin: {JSON.stringify(account)}
          </Typography>
        </Paper>
      )}

      <Paper sx={{ p: 2, borderRadius: 2 }}>
        <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
          История операций
        </Typography>
        <TableContainer>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Тип</TableCell>
                <TableCell>Сумма</TableCell>
                <TableCell>Описание</TableCell>
                <TableCell>Дата</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {ledger.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={4}>
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
                      <TableCell>
                        {String(e.amount_cents ?? '')} {String(e.currency ?? '')}
                      </TableCell>
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
