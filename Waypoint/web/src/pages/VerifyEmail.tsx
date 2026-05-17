import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  TextField,
  Button,
  Alert,
  Paper,
  useTheme,
  Link as MuiLink,
} from '@mui/material';
import { MarkEmailReadOutlined } from '@mui/icons-material';
import { Link, useSearchParams } from 'react-router-dom';
import { useSnackbar } from 'notistack';
import authApi from '../services/authApi';

function extractApiError(err: unknown): string | null {
  const e = err as { response?: { data?: unknown } };
  const data = e.response?.data;
  if (!data || typeof data !== 'object') return null;
  const obj = data as Record<string, unknown>;
  const direct = obj.error ?? obj.message;
  if (typeof direct === 'string' && direct.trim()) return direct.trim();
  return null;
}

export default function VerifyEmail() {
  const theme = useTheme();
  const { enqueueSnackbar } = useSnackbar();
  const [searchParams] = useSearchParams();
  const qpEmail = searchParams.get('email') ?? '';

  const [email, setEmail] = useState(qpEmail);
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [resendSec, setResendSec] = useState(0);

  useEffect(() => {
    setEmail(qpEmail);
  }, [qpEmail]);

  useEffect(() => {
    if (resendSec <= 0) return;
    const t = setTimeout(() => setResendSec((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [resendSec]);

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const { data } = await authApi.post<{ token: string }>('/auth/register/verify', {
        email: email.trim().toLowerCase(),
        code: code.replace(/\s/g, ''),
      });
      if (data && typeof data === 'object' && 'token' in data) {
        enqueueSnackbar('Email подтверждён. Добро пожаловать.', { variant: 'success' });
        window.location.href = '/dashboard/onboarding';
      }
    } catch (err: unknown) {
      const msg = extractApiError(err) ?? 'Не удалось подтвердить. Проверьте код.';
      setError(msg);
      enqueueSnackbar(msg, { variant: 'error' });
    } finally {
      setLoading(false);
    }
  };

  const handleResend = async () => {
    if (resendSec > 0 || !email.trim()) return;
    setError('');
    setLoading(true);
    try {
      await authApi.post('/auth/register/resend', { email: email.trim().toLowerCase() });
      enqueueSnackbar('Если аккаунт есть, код отправлен.', { variant: 'info' });
      setResendSec(60);
    } catch (err: unknown) {
      const msg = extractApiError(err) ?? 'Не удалось отправить';
      setError(msg);
      enqueueSnackbar(msg, { variant: 'error' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        py: 2,
        background: `radial-gradient(ellipse at 50% 50%, ${theme.palette.background.paper} 0%, ${theme.palette.background.default} 100%)`,
      }}
    >
      <Box component="main" sx={{ width: '100%', maxWidth: 420, mx: 'auto', px: 2 }}>
        <MuiLink component={Link} to="/register" sx={{ display: 'block', mb: 1, fontSize: 14 }}>
          ← К регистрации
        </MuiLink>
        <Paper elevation={0} sx={{ p: { xs: 2.5, sm: 4 }, borderRadius: 4, border: `1px solid ${theme.palette.divider}` }}>
          <Box sx={{ textAlign: 'center', mb: 2 }}>
            <MarkEmailReadOutlined sx={{ fontSize: 48, color: 'primary.main' }} />
            <Typography variant="h5" sx={{ mt: 1, fontWeight: 700 }}>
              Подтвердите email
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
              Введите 8-значный код из письма. Без подтверждения вход недоступен.
            </Typography>
          </Box>
          {error && (
            <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>
              {error}
            </Alert>
          )}
          <Box component="form" onSubmit={(e) => void handleVerify(e)}>
            <TextField
              margin="normal"
              required
              fullWidth
              label="Email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
            <TextField
              margin="normal"
              required
              fullWidth
              label="Код из письма"
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 8))}
              inputProps={{ maxLength: 8, inputMode: 'numeric' }}
            />
            <Button type="submit" fullWidth variant="contained" disabled={loading} sx={{ mt: 2, py: 1.5 }}>
              {loading ? 'Проверка…' : 'Подтвердить'}
            </Button>
            <Button fullWidth sx={{ mt: 1 }} disabled={loading || resendSec > 0} onClick={() => void handleResend()}>
              {resendSec > 0 ? `Отправить снова (${resendSec}с)` : 'Отправить код повторно'}
            </Button>
            <MuiLink component={Link} to="/login" sx={{ display: 'block', textAlign: 'center', mt: 2 }}>
              Уже подтвердили? Войти
            </MuiLink>
          </Box>
        </Paper>
      </Box>
    </Box>
  );
}
