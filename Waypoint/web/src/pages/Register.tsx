import React, { useState } from 'react';
import {
  Box,
  Typography,
  TextField,
  Button,
  Alert,
  Paper,
  InputAdornment,
  IconButton,
  useTheme,
  Link as MuiLink,
} from '@mui/material';
import { LockOutlined, Visibility, VisibilityOff, Person, Email } from '@mui/icons-material';
import { Link, useSearchParams } from 'react-router-dom';
import { useSnackbar } from 'notistack';
import authApi from '../services/authApi';
import { setPreferredPlan } from '../utils/preferredPlan';

function networkMessage(err: unknown): string | null {
  const e = err as { message?: string; code?: string; response?: unknown };
  if (e.response) return null;
  const m = e.message ?? '';
  if (e.code === 'ERR_NETWORK' || e.code === 'ECONNABORTED' || /network/i.test(m) || /ERR_CONNECTION/i.test(m)) {
    return 'Нет связи с сервером. Откройте сайт в браузере по обычному адресу и попробуйте снова.';
  }
  return null;
}

function extractApiError(err: unknown): string | null {
  const e = err as { response?: { status?: number; data?: unknown } };
  const data = e.response?.data;
  if (!data) return null;
  if (typeof data === 'string' && data.trim()) return data.trim();
  if (typeof data === 'object') {
    const obj = data as Record<string, unknown>;
    const direct = obj.error ?? obj.message ?? obj.detail;
    if (typeof direct === 'string' && direct.trim()) return direct.trim();
  }
  if (e.response?.status === 400) return 'Проверьте данные формы или войдите, если аккаунт уже есть.';
  if (e.response?.status) return 'Не удалось зарегистрироваться. Попробуйте позже.';
  return null;
}


export default function Register() {
  const [email, setEmail] = useState('');
  const [nickname, setNickname] = useState('');
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const theme = useTheme();
  const { enqueueSnackbar } = useSnackbar();
  const [searchParams] = useSearchParams();
  const preselectedPlan = searchParams.get('plan');

  const passwordHint =
    '≥10 символов, латиница: строчная и заглавная буквы, цифра и спецсимвол.';

  const handlePublicRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const { data } = await authApi.post<{ status?: string; email?: string; token?: string }>('/register', {
        email: email.trim(),
        nickname: nickname.trim(),
        full_name: fullName.trim(),
        password,
        phone: phone.trim() || null,
        settings: {},
      });
      if (data && typeof data === 'object' && data.status === 'pending_verification') {
        const em = (data.email ?? email).trim();
        enqueueSnackbar('Проверьте почту и введите код подтверждения.', { variant: 'info' });
        window.location.href = `/verify-email?email=${encodeURIComponent(em)}`;
        return;
      }
      if (!data || typeof data !== 'object' || !(data as { token?: string }).token) {
        enqueueSnackbar('Сервер ответил неожиданно. Попробуйте войти или повторите позже.', { variant: 'warning' });
        return;
      }
      enqueueSnackbar('Аккаунт создан. Добро пожаловать в WaypointMetric.', { variant: 'success' });
      setPreferredPlan(preselectedPlan);
      window.location.href = '/dashboard/onboarding';
    } catch (err: unknown) {
      const msg =
        extractApiError(err) ||
        networkMessage(err) ||
        'Регистрация не удалась. Проверьте данные и связь с сервером.';
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
      <Box component="main" sx={{ width: '100%', maxWidth: 420, mx: 'auto', px: { xs: 1.5, sm: 2 } }}>
        <MuiLink component={Link} to="/" sx={{ display: 'block', mb: 1, fontSize: 14 }}>
          ← Тарифы и описание
        </MuiLink>
        <Paper elevation={0} sx={{ p: { xs: 2.2, sm: 4 }, borderRadius: 4, border: `1px solid ${theme.palette.divider}` }}>
          <Box sx={{ textAlign: 'center', mb: 2 }}>
            <LockOutlined sx={{ fontSize: 48, color: 'primary.main' }} />
            <Typography variant="h5" sx={{ mt: 1, fontWeight: 700, fontSize: { xs: '1.35rem', sm: '1.5rem' } }}>
              WaypointMetric
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
              Создайте аккаунт — те же данные, что и в Lynx Launcher. Здесь — облако Metric: базы, метрики и файлы; сам
              <strong> 2D-движок и редактор</strong> — в лаунчере и Lynx Cloud (релизы ядра — раздел «Ядро Lynx» в
              админке). <strong>Полная админ-консоль</strong> (хост, задания, инстансы) — только у пользователей с ролью{' '}
              <strong>admin</strong>, назначаемой владельцем сервера.
            </Typography>
          </Box>

          {preselectedPlan === 'basic' || preselectedPlan === 'pro' ? (
            <Alert severity="info" sx={{ mb: 2 }}>
              Выбран тариф: <strong>{preselectedPlan === 'pro' ? 'Pro' : 'Basic'}</strong> — он подставится в шаге
              настройки workspace (если для Pro нужны права admin, откроется Basic до оплаты/активации).
            </Alert>
          ) : null}
          {error && (
            <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>
              {error}
            </Alert>
          )}
          <Box component="form" onSubmit={(e) => void handlePublicRegister(e)}>
            <TextField
              margin="normal"
              required
              fullWidth
              label="Email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <Email color="action" />
                  </InputAdornment>
                ),
              }}
            />
            <TextField
              margin="normal"
              required
              fullWidth
              label="Никнейм"
              value={nickname}
              onChange={(e) => setNickname(e.target.value)}
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
              label="Полное имя"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
            />
            <TextField
              margin="normal"
              fullWidth
              label="Телефон (необязательно, для SMS-кодов)"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
            />
            <TextField
              margin="normal"
              required
              fullWidth
              label="Пароль"
              type={showPassword ? 'text' : 'password'}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              helperText={passwordHint}
              InputProps={{
                endAdornment: (
                  <InputAdornment position="end">
                    <IconButton onClick={() => setShowPassword(!showPassword)} edge="end">
                      {showPassword ? <VisibilityOff /> : <Visibility />}
                    </IconButton>
                  </InputAdornment>
                ),
              }}
            />
            <Button type="submit" fullWidth variant="contained" disabled={loading} sx={{ mt: 2, py: 1.5 }}>
              {loading ? 'Регистрация…' : 'Зарегистрироваться'}
            </Button>
            <MuiLink component={Link} to="/login" sx={{ display: 'block', textAlign: 'center', mt: 2 }}>
              Уже есть аккаунт? Войти
            </MuiLink>
            <MuiLink component={Link} to="/auth/nexus" sx={{ display: 'block', textAlign: 'center', mt: 1 }}>
              Войти через Lynx Auth
            </MuiLink>
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', textAlign: 'center', mt: 2 }}>
              Админ-доступ активируется отдельным ключом из 60 символов в разделе «Настройки».
            </Typography>
          </Box>
        </Paper>
      </Box>
    </Box>
  );
}
