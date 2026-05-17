import React, { useEffect, useState } from 'react';
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
  CircularProgress,
} from '@mui/material';
import { Visibility, VisibilityOff, Person, Email } from '@mui/icons-material';
import { Link, useNavigate } from 'react-router-dom';
import { useSnackbar } from 'notistack';
import authApi from '../services/authApi';


export default function RegisterStaff() {
  const [email, setEmail] = useState('');
  const [nickname, setNickname] = useState('');
  const [fullName, setFullName] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState<boolean | null>(null);
  const theme = useTheme();
  const navigate = useNavigate();
  const { enqueueSnackbar } = useSnackbar();

  useEffect(() => {
    let c = false;
    (async () => {
      try {
        const { data } = await authApi.get<{ open: boolean }>('/admin/registration-status');
        if (!c) setOpen(data.open);
      } catch {
        if (!c) setOpen(false);
      }
    })();
    return () => {
      c = true;
    };
  }, []);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const { data } = await authApi.post<{ token: string }>('/admin/register', {
        email: email.trim(),
        nickname: nickname.trim(),
        full_name: fullName.trim(),
        password,
      });
      enqueueSnackbar('Администратор зарегистрирован.', { variant: 'success' });
      navigate('/dashboard');
    } catch (err: unknown) {
      const ax = err as { response?: { data?: { error?: string } }; message?: string };
      const msg =
        ax.response?.data?.error ||
        (ax.message?.includes('Network') ? 'Нет связи с сервером.' : null) ||
        'Ошибка регистрации';
      setError(msg);
      enqueueSnackbar(msg, { variant: 'error' });
    } finally {
      setLoading(false);
    }
  };

  if (open === null) {
    return (
      <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <CircularProgress />
      </Box>
    );
  }

  if (open === false) {
    return (
      <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', p: 2 }}>
        <Paper sx={{ p: 4, maxWidth: 520 }}>
          <Typography variant="h6" gutterBottom>
            Регистрация администратора недоступна
          </Typography>
          <Alert severity="info" sx={{ my: 2 }}>
            На сервере выключена саморегистрация админов. Назначьте роль <code>admin</code> вручную в БД или временно
            установите <code>ADMIN_OPEN_REGISTRATION=1</code> в окружении API.
          </Alert>
          <MuiLink component={Link} to="/login">
            На страницу входа
          </MuiLink>
        </Paper>
      </Box>
    );
  }

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        background: `radial-gradient(ellipse at 50% 50%, ${theme.palette.background.paper} 0%, ${theme.palette.background.default} 100%)`,
      }}
    >
      <Box component="main" sx={{ width: '100%', maxWidth: 420, mx: 'auto', px: 2 }}>
        <Paper elevation={0} sx={{ p: 4, borderRadius: 4, border: `1px solid ${theme.palette.divider}` }}>
          <Typography variant="h5" sx={{ fontWeight: 700 }} gutterBottom>
            Регистрация администратора
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            WaypointMetric — полный доступ к консоли только для назначенных администраторов. Эта страница — для первичной
            настройки сервера.
          </Typography>
          {error && (
            <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>
              {error}
            </Alert>
          )}
          <Box component="form" onSubmit={(e) => void submit(e)}>
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
              required
              fullWidth
              label="Пароль"
              type={showPassword ? 'text' : 'password'}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
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
              {loading ? '…' : 'Создать администратора'}
            </Button>
            <MuiLink component={Link} to="/login" sx={{ display: 'block', textAlign: 'center', mt: 2 }}>
              Войти
            </MuiLink>
            <MuiLink component={Link} to="/register" sx={{ display: 'block', textAlign: 'center', mt: 1 }}>
              Обычная регистрация
            </MuiLink>
          </Box>
        </Paper>
      </Box>
    </Box>
  );
}
