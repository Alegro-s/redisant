import React, { useEffect, useRef } from 'react';
import {
  Box,
  Button,
  Chip,
  Grid,
  Paper,
  Stack,
  TextField,
  Typography,
  Alert,
  Stepper,
  Step,
  StepLabel,
} from '@mui/material';
import { Cloud, Dns, CheckCircle } from '@mui/icons-material';
import { Link as RouterLink, useNavigate } from 'react-router-dom';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { useAuth } from '../../app/contexts/AuthContext';
import { PremiumIconBadge } from '../../components/common/PremiumIconBadge';
import { consumePreferredPlan } from '../../utils/preferredPlan';
import { useNotification } from '../../app/hooks/useNotification';

const STEPS = ['Тариф', 'Сервер', 'Готово'];

export const Onboarding: React.FC = () => {
  const navigate = useNavigate();
  const { isAdmin } = useAuth();
  const { workspace, saveWorkspace, isLoading } = useWorkspace();
  const { showError } = useNotification();
  const proAllowed = isAdmin;
  const appliedLandingPlan = useRef(false);
  const [connectionUrl, setConnectionUrl] = React.useState<string>(workspace.connectionUrl ?? '');

  const activeStep = !workspace.plan
    ? 0
    : !workspace.serverConnected
      ? 1
      : 2;

  useEffect(() => {
    if (appliedLandingPlan.current || isLoading || workspace.setupCompleted) return;
    const fromLanding = consumePreferredPlan();
    if (!fromLanding) return;
    appliedLandingPlan.current = true;
    void saveWorkspace({ plan: fromLanding === 'pro' && !proAllowed ? 'basic' : fromLanding });
  }, [isLoading, workspace.setupCompleted, proAllowed, saveWorkspace]);

  const finish = async () => {
    const ok = await saveWorkspace({ setupCompleted: true });
    if (!ok) {
      showError('Не удалось сохранить. Проверьте интернет и попробуйте снова.');
      return;
    }
    navigate('/dashboard', { replace: true });
  };

  const cardSx = {
    p: 2.5,
    borderRadius: 2,
    height: '100%',
    display: 'flex',
    flexDirection: 'column' as const,
  };

  return (
    <Box sx={{ maxWidth: 800, mx: 'auto', py: { xs: 2, md: 3 }, px: { xs: 2, sm: 3 } }}>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 0.5 }}>
        Настройка облака
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3, lineHeight: 1.6 }}>
        Три шага: тариф → сервер (для БД и метрик) → рабочий стол. Waypoint Desktop ставится отдельно.
      </Typography>

      <Stepper activeStep={activeStep} sx={{ mb: 3 }}>
        {STEPS.map((label) => (
          <Step key={label}>
            <StepLabel>{label}</StepLabel>
          </Step>
        ))}
      </Stepper>

      <Paper sx={{ p: 2.5, borderRadius: 2, mb: 2 }}>
        <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
          1. Тариф
        </Typography>
        <Stack direction="row" spacing={1} sx={{ mb: 1.5 }}>
          <Chip
            label="Basic"
            color={workspace.plan === 'basic' ? 'primary' : 'default'}
            onClick={() => void saveWorkspace({ plan: 'basic' })}
          />
          <Chip
            label="Pro"
            color={workspace.plan === 'pro' ? 'primary' : 'default'}
            disabled={!proAllowed}
            onClick={() => void saveWorkspace({ plan: 'pro' })}
          />
        </Stack>
        <Button component={RouterLink} to="/dashboard/billing" size="small" variant="text">
          Подробнее о тарифах и оплате
        </Button>
        {!proAllowed && (
          <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 1 }}>
            Pro на этапе бета — по запросу или для admin-аккаунта.
          </Typography>
        )}
      </Paper>

      <Grid container spacing={2}>
        <Grid item xs={12} md={6} sx={{ display: 'flex' }}>
          <Paper sx={cardSx}>
            <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1 }}>
              <PremiumIconBadge icon={<Cloud fontSize="small" />} />
              <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                Облако Waypoint
              </Typography>
            </Stack>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2, flex: 1 }}>
              Готовый сервер: база, метрики и файлы без настройки на своём ПК.
            </Typography>
            <Button
              variant="contained"
              fullWidth
              disabled={isLoading}
              sx={{ mt: 'auto' }}
              onClick={() =>
                void saveWorkspace({
                  setupMode: 'rent',
                  serverConnected: true,
                  plan: proAllowed ? workspace.plan : 'basic',
                })
              }
            >
              Включить аренду
            </Button>
          </Paper>
        </Grid>
        <Grid item xs={12} md={6} sx={{ display: 'flex' }}>
          <Paper sx={cardSx}>
            <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1 }}>
              <PremiumIconBadge icon={<Dns fontSize="small" />} />
              <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                Свой компьютер
              </Typography>
            </Stack>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
              Установите агент Waypoint — данные будут синхронизироваться с облаком.
            </Typography>
            <TextField
              fullWidth
              size="small"
              label="Код подключения агента"
              placeholder="из приложения Desktop"
              value={connectionUrl}
              onChange={(e) => setConnectionUrl(e.target.value)}
              sx={{ mb: 1.5 }}
            />
            <Button
              variant="outlined"
              fullWidth
              disabled={isLoading}
              sx={{ mt: 'auto' }}
              onClick={() =>
                void saveWorkspace({
                  setupMode: 'connect',
                  serverConnected: true,
                  connectionUrl: connectionUrl.trim() || null,
                })
              }
            >
              Подключить
            </Button>
          </Paper>
        </Grid>
      </Grid>

      <Paper sx={{ p: 2.5, borderRadius: 2, mt: 2 }}>
        <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
          3. Готово
        </Typography>
        {workspace.serverConnected ? (
          <Alert severity="success" sx={{ mb: 2 }}>
            Сервер подключён. Дальше: метрики, база данных и привязка Desktop.
          </Alert>
        ) : (
          <Alert severity="warning" sx={{ mb: 2 }}>
            Выберите аренду в облаке или подключите свой сервер.
          </Alert>
        )}
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} sx={{ alignItems: { sm: 'center' } }}>
          <Button
            variant="contained"
            startIcon={<CheckCircle />}
            disabled={!workspace.serverConnected || isLoading}
            onClick={() => void finish()}
            sx={{ minWidth: { sm: 220 } }}
          >
            Открыть рабочий стол
          </Button>
          <Button
            component={RouterLink}
            to="/dashboard/database"
            variant="outlined"
            disabled={!workspace.serverConnected}
            sx={{ minWidth: { sm: 160 } }}
          >
            База данных
          </Button>
          <Button component={RouterLink} to="/desktop/releases" variant="text" sx={{ minWidth: { sm: 160 } }}>
            Скачать Desktop
          </Button>
        </Stack>
      </Paper>
    </Box>
  );
};
