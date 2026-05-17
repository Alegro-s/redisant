import React, { useState } from 'react';
import {
  Container,
  Box,
  Avatar,
  Typography,
  TextField,
  Button,
  Alert,
  Paper,
  InputAdornment,
  IconButton,
  useTheme,
  Link,
  Stack,
} from '@mui/material';
import { LockOutlined, Visibility, VisibilityOff, Person } from '@mui/icons-material';
import { Link as RouterLink, useNavigate, useSearchParams } from 'react-router-dom';
import { useSnackbar } from 'notistack';
import { useAuth } from '../app/contexts/AuthContext';
import { setPreferredPlan } from '../utils/preferredPlan';

function friendlyError(err: unknown): string {
  const ax = err as {
    response?: { data?: { error?: string } };
    message?: string;
    code?: string;
  };
  if (ax.response?.data?.error) return ax.response.data.error;
  if (!ax.response && (ax.code === 'ERR_NETWORK' || ax.code === 'ECONNABORTED')) {
    return 'Нет связи с сервером. Откройте консоль по адресу сайта (не file://); API должен проксироваться с того же хоста на /api.';
  }
  const m = ax.message ?? '';
  if (/network/i.test(m) || /ERR_CONNECTION/i.test(m)) {
    return 'Нет связи с сервером. Проверьте nginx и прокси /api → порт API. В билде не должно оставаться localhost как хост API на прод-сайте.';
  }
  return 'Неверный логин или пароль.';
}

export default function Login() {
  const [login, setLogin] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { login: authLogin } = useAuth();
  const theme = useTheme();
  const { enqueueSnackbar } = useSnackbar();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await authLogin(login, password);
      enqueueSnackbar('Вход выполнен.', { variant: 'success' });
      setPreferredPlan(searchParams.get('plan'));
      navigate('/dashboard/onboarding');
    } catch (err: unknown) {
      const ax = err as {
        response?: { status?: number; data?: { error_code?: string; email?: string } };
      };
      if (ax.response?.status === 403 && ax.response.data?.error_code === 'email_not_verified') {
        const em = String(ax.response.data.email ?? login.trim());
        navigate(`/verify-email?email=${encodeURIComponent(em)}`);
        setLoading(false);
        return;
      }
      const msg = friendlyError(err);
      setError(msg);
      enqueueSnackbar(msg, { variant: 'error', autoHideDuration: 8000 });
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: { xs: 'flex-start', sm: 'center' },
        py: { xs: 2.5, sm: 0 },
        background: `radial-gradient(ellipse at 50% 50%, ${theme.palette.background.paper} 0%, ${theme.palette.background.default} 100%)`,
      }}
    >
      <Container component="main" maxWidth="xs" sx={{ px: { xs: 1.5, sm: 2 } }}>
        <Button component={RouterLink} to="/" size="small" sx={{ mb: 1, px: 0 }}>
          ← Тарифы и описание
        </Button>
        <Paper
          elevation={0}
          sx={{
            p: { xs: 2.2, sm: 4 },
            borderRadius: 4,
            border: `1px solid ${theme.palette.divider}`,
          }}
        >
          <Box sx={{ textAlign: 'center', mb: 3 }}>
            <Avatar
              sx={{
                m: 'auto',
                width: 64,
                height: 64,
                bgcolor: 'primary.main',
                mb: 2,
              }}
            >
              <LockOutlined sx={{ fontSize: 32 }} />
            </Avatar>
            <Typography variant="h5" sx={{ fontWeight: 800, color: 'primary.main', fontSize: { xs: '1.35rem', sm: '1.5rem' } }}>
              WaypointMetric
            </Typography>
            <Typography variant="caption" color="text.secondary" sx={{ mt: 0.5, display: 'block' }}>
              метрики, логи, BaaS — не панель движка
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 1.5 }}>
              Email или ник и пароль — те же, что в клиенте Lynx. Расширенные разделы (хост, задания, инстансы, AI)
              видны только пользователям с ролью <strong>admin</strong>.
            </Typography>
          </Box>

          {error && (
            <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError('')}>
              {error}
            </Alert>
          )}

          <Box component="form" onSubmit={(e) => void handleSubmit(e)}>
            <TextField
              margin="normal"
              required
              fullWidth
              label="Email или никнейм"
              value={login}
              onChange={(e) => setLogin(e.target.value)}
              autoComplete="username"
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <Person color="action" />
                  </InputAdornment>
                ),
              }}
            />
            <TextField
              margin="normal"
              required
              fullWidth
              label="Пароль"
              type={showPassword ? 'text' : 'password'}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              InputProps={{
                endAdornment: (
                  <InputAdornment position="end">
                    <IconButton onClick={() => setShowPassword(!showPassword)} edge="end" aria-label="показать пароль">
                      {showPassword ? <VisibilityOff /> : <Visibility />}
                    </IconButton>
                  </InputAdornment>
                ),
              }}
            />
            <Button
              type="submit"
              fullWidth
              variant="contained"
              disabled={loading}
              sx={{ mt: 3, mb: 1, py: 1.45 }}
            >
              {loading ? 'Вход…' : 'Войти'}
            </Button>
            <Stack spacing={1} sx={{ mt: 2 }}>
              <Button
                fullWidth
                variant="outlined"
                component={RouterLink}
                to="/auth/nexus"
              >
                Войти через Lynx Auth
              </Button>
              <Link component={RouterLink} to="/register" sx={{ display: 'block', textAlign: 'center' }}>
                Создать аккаунт
              </Link>
            </Stack>
          </Box>
        </Paper>
      </Container>
    </Box>
  );
}
