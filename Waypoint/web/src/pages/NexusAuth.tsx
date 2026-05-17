import React, { useState } from 'react';
import {
  Box,
  Paper,
  Typography,
  TextField,
  Button,
  Alert,
  Stepper,
  Step,
  StepLabel,
  InputAdornment,
  IconButton,
  Stack,
  Link,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
} from '@mui/material';
import { Visibility, VisibilityOff, Smartphone, ContentCopy, OpenInNew } from '@mui/icons-material';
import { Link as RouterLink, useNavigate } from 'react-router-dom';
import { useSnackbar } from 'notistack';
import api from '../services/api';

const NEXUS_DEEP_SCHEME = 'nexus://nexus-auth';

function buildDeepLink(challengeId: string, sessionToken: string, apiOrigin: string): string {
  const params = new URLSearchParams({
    challenge_id: challengeId,
    session_token: sessionToken,
    api_base: apiOrigin,
  });
  return `${NEXUS_DEEP_SCHEME}?${params.toString()}`;
}


export default function NexusAuth() {
  const navigate = useNavigate();
  const { enqueueSnackbar } = useSnackbar();
  const [step, setStep] = useState(0);
  const [login, setLogin] = useState('');
  const [password, setPassword] = useState('');
  const [showPw, setShowPw] = useState(false);
  const [code, setCode] = useState('');
  const [challengeId, setChallengeId] = useState<string | null>(null);
  const [sessionToken, setSessionToken] = useState<string | null>(null);
  const [deepLink, setDeepLink] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [launchDialog, setLaunchDialog] = useState(false);

  const apiPublicOrigin = typeof window !== 'undefined' ? `${window.location.origin}/api` : '/api';

  const notifyErr = (message: string) => {
    setErr(message);
    enqueueSnackbar(message, { variant: 'error', autoHideDuration: 6000 });
  };

  const preview = async () => {
    setErr(null);
    setLoading(true);
    try {
      await api.post('/auth/login/challenge-preview', { login: login.trim(), password });
      setStep(1);
      enqueueSnackbar('Пароль принят. Запросите код через приложение Lynx.', { variant: 'success' });
    } catch (e: unknown) {
      const ax = e as { response?: { data?: { error?: string } }; message?: string };
      const msg =
        ax.response?.data?.error ||
        (ax.message?.includes('Network') ? 'Нет связи с сервером. Проверьте сеть и адрес сайта.' : null) ||
        'Не удалось проверить учётные данные.';
      notifyErr(msg);
    } finally {
      setLoading(false);
    }
  };

  const startNexus = async () => {
    setErr(null);
    setLoading(true);
    try {
      const { data } = await api.post<{
        challenge_id: string;
        session_token: string;
        delivery_hint?: string;
      }>('/auth/login/challenge', {
        login: login.trim(),
        password,
        channel: 'nexus',
      });
      setChallengeId(data.challenge_id);
      setSessionToken(data.session_token);
      const link = buildDeepLink(data.challenge_id, data.session_token, apiPublicOrigin);
      setDeepLink(link);
      setStep(2);
      enqueueSnackbar(data.delivery_hint || 'Откройте приложение Lynx или введите код ниже.', {
        variant: 'info',
      });
    } catch (e: unknown) {
      const ax = e as {
        response?: { status?: number; data?: { error?: string; error_code?: string; email?: string } };
      };
      if (ax.response?.status === 403 && ax.response.data?.error_code === 'email_not_verified') {
        const em = String(ax.response.data.email ?? login.trim());
        navigate(`/verify-email?email=${encodeURIComponent(em)}`);
        setLoading(false);
        return;
      }
      notifyErr(ax.response?.data?.error || 'Не удалось создать сессию Lynx Auth.');
    } finally {
      setLoading(false);
    }
  };

  const openAppDeepLink = () => {
    if (!deepLink) return;
    try {
      window.location.href = deepLink;
      enqueueSnackbar(
        'Если приложение не открылось — установите Lynx, скопируйте ссылку или введите код вручную.',
        { variant: 'warning', autoHideDuration: 8000 },
      );
    } catch {
      notifyErr('Не удалось открыть deep link.');
    }
  };

  const tryOpenApp = () => {
    if (!deepLink) return;
    setLaunchDialog(true);
  };

  const copyLink = async () => {
    if (!deepLink) return;
    try {
      await navigator.clipboard.writeText(deepLink);
      enqueueSnackbar('Ссылка скопирована — вставьте её на телефоне с установленным Lynx.', {
        variant: 'success',
      });
    } catch {
      notifyErr('Копирование недоступно — выделите ссылку вручную.');
    }
  };

  const pollCode = async () => {
    if (!challengeId || !sessionToken) return;
    setLoading(true);
    setErr(null);
    try {
      const { data } = await api.get<{ code?: string }>('/auth/challenge/nexus-code', {
        params: { challenge_id: challengeId, session_token: sessionToken },
      });
      const c = data.code?.toString() ?? '';
      if (c.length === 6) {
        setCode(c);
        enqueueSnackbar('Код получен из Lynx Auth.', { variant: 'success' });
      } else {
        notifyErr('Код ещё не готов — откройте экран подтверждения в приложении Lynx.');
      }
    } catch (e: unknown) {
      const ax = e as { response?: { data?: { error?: string } } };
      notifyErr(ax.response?.data?.error || 'Код пока недоступен.');
    } finally {
      setLoading(false);
    }
  };

  const verify = async () => {
    if (!challengeId || !sessionToken) return;
    const raw = code.replace(/\s/g, '');
    if (raw.length !== 6) {
      notifyErr('Введите 6 цифр кода.');
      return;
    }
    setLoading(true);
    setErr(null);
    try {
      const { data } = await api.post<{ token?: string }>('/auth/login/verify', {
        challenge_id: challengeId,
        session_token: sessionToken,
        code: raw,
      });
      const t = data.token;
      if (!t) {
        notifyErr('Сервер не вернул токен.');
        return;
      }
      enqueueSnackbar('Вход выполнен.', { variant: 'success' });
      window.location.href = '/dashboard';
    } catch (e: unknown) {
      const ax = e as { response?: { data?: { error?: string } } };
      notifyErr(ax.response?.data?.error || 'Неверный или просроченный код.');
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
        justifyContent: 'center',
        p: { xs: 1.5, sm: 2 },
        pt: { xs: 2.5, sm: 2 },
        bgcolor: 'background.default',
      }}
    >
      <Paper sx={{ maxWidth: 480, width: 1, p: { xs: 2.1, sm: 3 } }}>
        <Typography variant="h5" fontWeight={700} gutterBottom>
          Lynx Auth
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Вход с одноразовым кодом из <strong>Lynx Launcher</strong> и веб-консоль WaypointMetric. Тот же email/ник, что в
          лаунчере. Deep link может использовать схему <code>nexus://</code> для совместимости со старыми сборками.
        </Typography>
        <Stepper activeStep={step} sx={{ mb: 3, display: { xs: 'none', sm: 'flex' } }}>
          <Step>
            <StepLabel>Пароль</StepLabel>
          </Step>
          <Step>
            <StepLabel>Сессия</StepLabel>
          </Step>
          <Step>
            <StepLabel>Код</StepLabel>
          </Step>
        </Stepper>
        <Typography variant="caption" color="text.secondary" sx={{ display: { xs: 'block', sm: 'none' }, mb: 2 }}>
          Шаг {step + 1} из 3
        </Typography>

        {err && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={() => setErr(null)}>
            {err}
          </Alert>
        )}

        {step === 0 && (
          <Stack spacing={2}>
            <TextField
              label="Email или никнейм"
              fullWidth
              value={login}
              onChange={(e) => setLogin(e.target.value)}
              autoComplete="username"
            />
            <TextField
              label="Пароль"
              type={showPw ? 'text' : 'password'}
              fullWidth
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              InputProps={{
                endAdornment: (
                  <InputAdornment position="end">
                    <IconButton onClick={() => setShowPw((s) => !s)} edge="end" aria-label="показать пароль">
                      {showPw ? <VisibilityOff /> : <Visibility />}
                    </IconButton>
                  </InputAdornment>
                ),
              }}
            />
            <Button variant="contained" disabled={loading || !login.trim() || password.length < 3} onClick={() => void preview()}>
              Продолжить
            </Button>
          </Stack>
        )}

        {step === 1 && (
          <Stack spacing={2}>
            <Alert severity="info">
              Дальше будет создана сессия с каналом <strong>Lynx</strong> (в API: <code>nexus</code>). Код подтверждения вы получите в Lynx Launcher
              (или сможете запросить его здесь после открытия приложения).
            </Alert>
            <Button variant="contained" startIcon={<Smartphone />} disabled={loading} onClick={() => void startNexus()}>
              Запросить код через Lynx
            </Button>
            <Button variant="text" onClick={() => setStep(0)} disabled={loading}>
              Назад
            </Button>
          </Stack>
        )}

        {step === 2 && (
          <Stack spacing={2}>
            <Alert severity="info">
              Откройте Lynx Launcher на телефоне. Если на устройстве настроена схема{' '}
              <code>{NEXUS_DEEP_SCHEME}</code>, нажмите «Открыть в приложении». Иначе скопируйте ссылку и откройте её на
              телефоне, либо введите 6 цифр, которые показаны в приложении после подтверждения входа.
            </Alert>
            {deepLink && (
              <TextField
                label="Deep link для приложения"
                fullWidth
                size="small"
                value={deepLink}
                InputProps={{ readOnly: true }}
              />
            )}
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
              <Button variant="contained" startIcon={<OpenInNew />} onClick={tryOpenApp} disabled={!deepLink}>
                Открыть в приложении
              </Button>
              <Button variant="outlined" startIcon={<ContentCopy />} onClick={() => void copyLink()} disabled={!deepLink}>
                Копировать ссылку
              </Button>
              <Button variant="outlined" onClick={() => void pollCode()} disabled={loading}>
                Запросить код с сервера
              </Button>
            </Stack>
            <TextField
              label="Код из приложения (6 цифр)"
              fullWidth
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
              inputProps={{ inputMode: 'numeric', maxLength: 6 }}
            />
            <Button variant="contained" disabled={loading || code.replace(/\s/g, '').length !== 6} onClick={() => void verify()}>
              Войти
            </Button>
            <Button variant="text" onClick={() => setStep(1)} disabled={loading}>
              Назад
            </Button>
          </Stack>
        )}

        <Box sx={{ mt: 3, textAlign: 'center' }}>
          <Link component={RouterLink} to="/login">
            Обычный вход
          </Link>
          {' · '}
          <Link component={RouterLink} to="/register">
            Регистрация
          </Link>
        </Box>
      </Paper>

      <Dialog open={launchDialog} onClose={() => setLaunchDialog(false)} fullWidth maxWidth="xs">
        <DialogTitle>Открыть приложение Lynx?</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary">
            Система передаст сессию по схеме <code>nexus://</code> (совместимость). Подтвердите вход в приложении Lynx — там
            появится запрос авторизации. После подтверждения вы сможете запросить код здесь или ввести его вручную.
          </Typography>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setLaunchDialog(false)}>Отмена</Button>
          <Button
            variant="contained"
            onClick={() => {
              setLaunchDialog(false);
              openAppDeepLink();
            }}
          >
            Открыть
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
