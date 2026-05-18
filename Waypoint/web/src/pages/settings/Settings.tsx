import React, { useState } from 'react';
import {
  Alert,
  Box,
  Typography,
  Paper,
  Grid,
  Switch,
  TextField,
  Button,
  Divider,
  List,
  ListItem,
  ListItemText,
  ListItemIcon,
  ListItemSecondaryAction,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Stack,
} from '@mui/material';
import {
  DarkMode,
  Notifications,
  Security,
  Api,
  Person,
  Language,
  Save,
  Refresh,
  Hub,
  CheckCircle,
  RadioButtonUnchecked,
  CloudUpload,
} from '@mui/icons-material';
import { Link as RouterLink } from 'react-router-dom';
import { useThemeContext } from '../../app/contexts/ThemeContext';
import { useAuth } from '../../app/contexts/AuthContext';
import { useNotification } from '../../app/hooks/useNotification';
import api from '../../services/api';

export const Settings: React.FC = () => {
  const { mode, toggleTheme } = useThemeContext();
  const { user, linkRealm, activateAdminKey, activateNexusKey, isAdmin, isNexus } = useAuth();
  const { showSuccess, showError } = useNotification();

  const [notifications, setNotifications] = useState({
    emailAlerts: true,
    metricAlerts: true,
    systemUpdates: true,
    securityAlerts: true,
  });

  const [apiSettings, setApiSettings] = useState({
    rateLimit: 100,
    corsOrigins: '*',
    enableMetrics: true,
  });

  const [linkOpen, setLinkOpen] = useState(false);
  const [linkRealmTarget, setLinkRealmTarget] = useState<'nexus' | 'metric' | null>(null);
  const [linkPassword, setLinkPassword] = useState('');
  const [linkBusy, setLinkBusy] = useState(false);
  const [adminKey, setAdminKey] = useState('');
  const [adminBusy, setAdminBusy] = useState(false);
  const [nexusKey, setNexusKey] = useState('');
  const [nexusBusy, setNexusBusy] = useState(false);
  const [hostingNote, setHostingNote] = useState('');
  const [hostingBusy, setHostingBusy] = useState(false);

  const hasRealm = (r: string) => (user?.realms ?? []).includes(r);

  const submitHostingRequest = async () => {
    setHostingBusy(true);
    try {
      await api.post('/me/hosting/request', { note: hostingNote.trim() || undefined });
      showSuccess('Заявка на аренду сервера отправлена');
      setHostingNote('');
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? String((e as { response?: { data?: { error?: string } } }).response?.data?.error ?? 'Ошибка')
          : 'Не удалось отправить заявку';
      showError(msg);
    } finally {
      setHostingBusy(false);
    }
  };

  const openLinkDialog = (r: 'nexus' | 'metric') => {
    setLinkRealmTarget(r);
    setLinkPassword('');
    setLinkOpen(true);
  };

  const submitLinkRealm = async () => {
    if (!linkRealmTarget || !linkPassword.trim()) {
      showError('Введите пароль');
      return;
    }
    setLinkBusy(true);
    try {
      await linkRealm(linkRealmTarget, linkPassword);
      setLinkOpen(false);
      showSuccess(
        linkRealmTarget === 'nexus'
          ? 'Клиент Lynx подключён к этому логину'
          : 'WaypointMetric подключён к этому логину',
      );
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? String((e as { response?: { data?: { error?: string } } }).response?.data?.error ?? 'Ошибка')
          : 'Не удалось подключить';
      showError(msg);
    } finally {
      setLinkBusy(false);
    }
  };

  const handleSaveSettings = () => {
    showSuccess('Settings saved successfully');
  };

  const submitAdminKey = async () => {
    const key = adminKey.trim();
    if (key.length !== 60) {
      showError('Ключ должен содержать ровно 60 символов');
      return;
    }
    setAdminBusy(true);
    try {
      await activateAdminKey(key);
      setAdminKey('');
      showSuccess('Права администратора активированы');
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? String((e as { response?: { data?: { error?: string } } }).response?.data?.error ?? 'Ошибка')
          : 'Не удалось активировать ключ';
      showError(msg);
    } finally {
      setAdminBusy(false);
    }
  };

  const submitNexusKey = async () => {
    const key = nexusKey.trim();
    if (key.length !== 60) {
      showError('Ключ должен содержать ровно 60 символов');
      return;
    }
    setNexusBusy(true);
    try {
      await activateNexusKey(key);
      setNexusKey('');
      showSuccess('Роль платформы Lynx (nexus) активирована');
    } catch (e: unknown) {
      const msg =
        e && typeof e === 'object' && 'response' in e
          ? String((e as { response?: { data?: { error?: string } } }).response?.data?.error ?? 'Ошибка')
          : 'Не удалось активировать ключ';
      showError(msg);
    } finally {
      setNexusBusy(false);
    }
  };

  return (
    <Box>
      <Box sx={{ mb: 3 }}>
        <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
          Settings
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Manage your account and system preferences
        </Typography>
      </Box>

      <Paper sx={{ p: 2, mb: 3, borderRadius: 3 }}>
        <Typography variant="subtitle1" fontWeight={600} gutterBottom>
          Waypoint Desktop
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
          Привязка ПК по коду WD-XXXXXXXX, отзыв API-ключей устройств.
        </Typography>
        <Button component={RouterLink} to="/dashboard/settings/devices" variant="outlined" size="small">
          Подключённые устройства
        </Button>
      </Paper>

      <Grid container spacing={3}>
        <Grid item xs={12} md={4}>
          <Paper sx={{ borderRadius: 3, overflow: 'hidden' }}>
            <List>
              <ListItem selected>
                <ListItemIcon><Person /></ListItemIcon>
                <ListItemText primary="Profile" secondary="Manage your profile" />
              </ListItem>
              <ListItem>
                <ListItemIcon><DarkMode /></ListItemIcon>
                <ListItemText primary="Appearance" secondary="Theme and display" />
              </ListItem>
              <ListItem>
                <ListItemIcon><Notifications /></ListItemIcon>
                <ListItemText primary="Notifications" secondary="Alert preferences" />
              </ListItem>
              <ListItem>
                <ListItemIcon><Api /></ListItemIcon>
                <ListItemText primary="API" secondary="API keys and limits" />
              </ListItem>
              <ListItem>
                <ListItemIcon><Security /></ListItemIcon>
                <ListItemText primary="Security" secondary="Authentication & access" />
              </ListItem>
              <ListItem>
                <ListItemIcon><Language /></ListItemIcon>
                <ListItemText primary="Language" secondary="Localization" />
              </ListItem>
            </List>
          </Paper>
        </Grid>

        <Grid item xs={12} md={8}>
          <Paper sx={{ p: 3, borderRadius: 3 }}>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
              Profile Settings
            </Typography>

            <Grid container spacing={3}>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Full Name"
                  defaultValue={user?.fullName}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Email"
                  defaultValue={user?.email}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Nickname"
                  defaultValue={user?.nickname}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Phone"
                  defaultValue=""
                />
              </Grid>
            </Grid>

            <Divider sx={{ my: 3 }} />

            <Typography variant="h6" sx={{ fontWeight: 600, mb: 1, display: 'flex', alignItems: 'center', gap: 1 }}>
              <CloudUpload fontSize="small" color="primary" />
              Аренда сервера
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2, maxWidth: 720, lineHeight: 1.65 }}>
              Заявка попадает в очередь администратора (без автоматического провижининга). Укажите желаемый регион или
              комментарий.
            </Typography>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'flex-start' }} sx={{ mb: 3 }}>
              <TextField
                label="Комментарий (необязательно)"
                placeholder="Например: EU, 4 vCPU, оценка сроков"
                value={hostingNote}
                onChange={(e) => setHostingNote(e.target.value)}
                fullWidth
                multiline
                minRows={2}
              />
              <Button
                variant="contained"
                disabled={hostingBusy}
                onClick={() => void submitHostingRequest()}
                sx={{ flexShrink: 0, alignSelf: { xs: 'stretch', sm: 'center' } }}
              >
                Заказать хостинг
              </Button>
            </Stack>

            <Divider sx={{ my: 3 }} />

            <Typography variant="h6" sx={{ fontWeight: 600, mb: 1 }}>
              Связь аккаунтов
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2, maxWidth: 720, lineHeight: 1.65 }}>
              Один email и пароль. Вы вошли в веб-консоль WaypointMetric; клиент Lynx — отдельное приложение. Пока не подключите
              второй продукт, войти в него этим логином нельзя. Ниже — как на GitHub при объединении двух способов входа в один
              аккаунт.
            </Typography>
            <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} alignItems="stretch" sx={{ mb: 1 }}>
              <Paper
                variant="outlined"
                sx={{
                  flex: 1,
                  p: 2,
                  borderRadius: 2,
                  borderColor: hasRealm('metric') ? 'primary.main' : 'divider',
                }}
              >
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
                  <Hub color="primary" fontSize="small" />
                  <Typography fontWeight={700}>WaypointMetric (веб)</Typography>
                  {hasRealm('metric') ? (
                    <CheckCircle color="primary" sx={{ ml: 'auto', fontSize: 22 }} />
                  ) : (
                    <RadioButtonUnchecked sx={{ ml: 'auto', fontSize: 22, opacity: 0.5 }} />
                  )}
                </Stack>
                <Typography variant="body2" color="text.secondary">
                  Текущий сайт и ingest. Обычно уже отмечено при регистрации здесь.
                </Typography>
                {!hasRealm('metric') && (
                  <Button size="small" sx={{ mt: 1 }} onClick={() => openLinkDialog('metric')}>
                    Подключить WaypointMetric
                  </Button>
                )}
              </Paper>
              <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', px: 1 }}>
                <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 700, textAlign: 'center' }}>
                  один
                  <br />
                  аккаунт
                </Typography>
              </Box>
              <Paper
                variant="outlined"
                sx={{
                  flex: 1,
                  p: 2,
                  borderRadius: 2,
                  borderColor: hasRealm('nexus') ? 'primary.main' : 'divider',
                }}
              >
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
                  <Hub color="primary" fontSize="small" />
                  <Typography fontWeight={700}>Lynx (клиент)</Typography>
                  {hasRealm('nexus') ? (
                    <CheckCircle color="primary" sx={{ ml: 'auto', fontSize: 22 }} />
                  ) : (
                    <RadioButtonUnchecked sx={{ ml: 'auto', fontSize: 22, opacity: 0.5 }} />
                  )}
                </Stack>
                <Typography variant="body2" color="text.secondary">
                  Приложение для ПК и телефонов: движок и проекты.
                </Typography>
                {!hasRealm('nexus') && (
                  <Button size="small" sx={{ mt: 1 }} onClick={() => openLinkDialog('nexus')}>
                    Подключить Lynx
                  </Button>
                )}
              </Paper>
            </Stack>

            <Divider sx={{ my: 3 }} />

            <Typography variant="h6" sx={{ fontWeight: 600, mb: 1 }}>
              Права администратора платформы Lynx
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2, maxWidth: 720, lineHeight: 1.65 }}>
              По умолчанию новый аккаунт имеет роль <strong>user</strong>. Для доступа к основным admin-разделам нужен ключ
              активации (60 символов), выданный владельцем платформы.
            </Typography>
            {isAdmin ? (
              <Alert severity="success" sx={{ mb: 2 }}>
                У этого аккаунта уже есть расширенные права (admin или роль платформы nexus).
              </Alert>
            ) : (
              <Stack direction={{ xs: 'column', md: 'row' }} spacing={1.5} sx={{ mb: 1 }}>
                <TextField
                  fullWidth
                  label="Admin key (60 chars)"
                  value={adminKey}
                  onChange={(e) => setAdminKey(e.target.value)}
                  inputProps={{ maxLength: 60 }}
                />
                <Button
                  variant="contained"
                  onClick={() => void submitAdminKey()}
                  disabled={adminBusy || adminKey.trim().length !== 60}
                >
                  Активировать
                </Button>
              </Stack>
            )}

            <Typography variant="h6" sx={{ fontWeight: 600, mb: 1, mt: 2 }}>
              Роль платформы Lynx (API: nexus)
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2, maxWidth: 720, lineHeight: 1.65 }}>
              Отдельный ключ для разработки ядра: политика релизов, расширенный доступ. Не заменяет admin для всех задач —
              выдайте ключ отдельно.
            </Typography>
            {isNexus ? (
              <Alert severity="info" sx={{ mb: 2 }}>
                Роль платформы уже активна.
              </Alert>
            ) : (
              <Stack direction={{ xs: 'column', md: 'row' }} spacing={1.5} sx={{ mb: 1 }}>
                <TextField
                  fullWidth
                  label="Ключ платформы Lynx (60 символов)"
                  value={nexusKey}
                  onChange={(e) => setNexusKey(e.target.value)}
                  inputProps={{ maxLength: 60 }}
                />
                <Button
                  variant="outlined"
                  onClick={() => void submitNexusKey()}
                  disabled={nexusBusy || nexusKey.trim().length !== 60}
                >
                  Активировать роль платформы
                </Button>
              </Stack>
            )}

            <Divider sx={{ my: 3 }} />

            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
              Appearance
            </Typography>

            <List>
              <ListItem>
                <ListItemIcon><DarkMode /></ListItemIcon>
                <ListItemText primary="Dark Mode" secondary="Toggle dark/light theme" />
                <ListItemSecondaryAction>
                  <Switch checked={mode === 'dark'} onChange={toggleTheme} />
                </ListItemSecondaryAction>
              </ListItem>
            </List>

            <Divider sx={{ my: 3 }} />

            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
              Notifications
            </Typography>

            <List>
              <ListItem>
                <ListItemText primary="Email Alerts" secondary="Receive email notifications" />
                <ListItemSecondaryAction>
                  <Switch
                    checked={notifications.emailAlerts}
                    onChange={(e) => setNotifications({ ...notifications, emailAlerts: e.target.checked })}
                  />
                </ListItemSecondaryAction>
              </ListItem>
              <ListItem>
                <ListItemText primary="Metric Alerts" secondary="Alert when metrics exceed thresholds" />
                <ListItemSecondaryAction>
                  <Switch
                    checked={notifications.metricAlerts}
                    onChange={(e) => setNotifications({ ...notifications, metricAlerts: e.target.checked })}
                  />
                </ListItemSecondaryAction>
              </ListItem>
              <ListItem>
                <ListItemText primary="System Updates" secondary="Get notified about system updates" />
                <ListItemSecondaryAction>
                  <Switch
                    checked={notifications.systemUpdates}
                    onChange={(e) => setNotifications({ ...notifications, systemUpdates: e.target.checked })}
                  />
                </ListItemSecondaryAction>
              </ListItem>
            </List>

            <Divider sx={{ my: 3 }} />

            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>
              API Settings
            </Typography>

            <Grid container spacing={3}>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="Rate Limit (requests/min)"
                  type="number"
                  value={apiSettings.rateLimit}
                  onChange={(e) => setApiSettings({ ...apiSettings, rateLimit: parseInt(e.target.value) })}
                />
              </Grid>
              <Grid item xs={12} md={6}>
                <TextField
                  fullWidth
                  label="CORS Origins"
                  value={apiSettings.corsOrigins}
                  onChange={(e) => setApiSettings({ ...apiSettings, corsOrigins: e.target.value })}
                />
              </Grid>
            </Grid>

            <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 2, mt: 3 }}>
              <Button variant="outlined" startIcon={<Refresh />}>
                Reset
              </Button>
              <Button variant="contained" startIcon={<Save />} onClick={handleSaveSettings}>
                Save Changes
              </Button>
            </Box>
          </Paper>
        </Grid>
      </Grid>

      <Dialog open={linkOpen} onClose={() => !linkBusy && setLinkOpen(false)} fullWidth maxWidth="xs">
        <DialogTitle>
          Подтвердить: {linkRealmTarget === 'nexus' ? 'подключить Lynx' : 'подключить Метрику'}
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2, lineHeight: 1.6 }}>
            Введите пароль этого аккаунта. После подключения один логин откроет оба продукта.
          </Typography>
          <TextField
            autoFocus
            fullWidth
            type="password"
            label="Пароль"
            value={linkPassword}
            onChange={(e) => setLinkPassword(e.target.value)}
          />
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setLinkOpen(false)} disabled={linkBusy}>
            Отмена
          </Button>
          <Button variant="contained" onClick={() => void submitLinkRealm()} disabled={linkBusy || !linkPassword.trim()}>
            Подключить
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};