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
} from '@mui/material';
import { Cloud, Dns, Science, CheckCircle } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { useAuth } from '../../app/contexts/AuthContext';
import { PremiumIconBadge } from '../../components/common/PremiumIconBadge';
import { consumePreferredPlan } from '../../utils/preferredPlan';
import { useNotification } from '../../app/hooks/useNotification';

export const Onboarding: React.FC = () => {
  const navigate = useNavigate();
  const { isAdmin } = useAuth();
  const { workspace, saveWorkspace, isLoading } = useWorkspace();
  const { showError } = useNotification();
  const proAllowed = isAdmin;
  const appliedLandingPlan = useRef(false);
  const [connectionUrl, setConnectionUrl] = React.useState<string>(workspace.connectionUrl ?? '');

  useEffect(() => {
    if (appliedLandingPlan.current || isLoading || workspace.setupCompleted) return;
    const fromLanding = consumePreferredPlan();
    if (!fromLanding) return;
    appliedLandingPlan.current = true;
    if (fromLanding === 'pro' && !proAllowed) {
      void saveWorkspace({ plan: 'basic' });
      return;
    }
    void saveWorkspace({ plan: fromLanding });
  }, [isLoading, workspace.setupCompleted, proAllowed, saveWorkspace]);

  return (
    <Box sx={{ maxWidth: 980, mx: 'auto', py: { xs: 2, md: 4 }, px: 2 }}>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
        Запуск рабочего пространства
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3 }}>
        Шаг 1: выбери аренду или подключение. Шаг 2: нажми тест кодовых баз. Шаг 3: переход в рабочий кабинет.
      </Typography>
      {!proAllowed && (
        <Alert severity="info" sx={{ mb: 2 }}>
          Тариф Pro и аренда расширенного сервера доступны только после активации admin/nexus доступа.
        </Alert>
      )}

      <Grid container spacing={2.5}>
        <Grid item xs={12} md={6}>
          <Paper sx={{ p: 3, borderRadius: 3 }}>
            <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1 }}>
              <PremiumIconBadge icon={<Cloud fontSize="small" />} />
              <Typography variant="h6" sx={{ fontWeight: 700 }}>Аренда сервера</Typography>
            </Stack>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
              Базовый тариф: 1 ядро, 10 ГБ. Выбери план и запусти workspace в пару кликов.
            </Typography>
            <Stack direction="row" spacing={1} sx={{ mb: 2 }}>
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
            {!proAllowed && (
              <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1.5 }}>
                Pro сейчас заблокирован: нужен admin/nexus доступ.
              </Typography>
            )}
            <Button
              variant="contained"
              disabled={isLoading}
              onClick={() =>
                void (async () => {
                  const ok = await saveWorkspace({
                    setupMode: 'rent',
                    serverConnected: true,
                    plan: proAllowed ? workspace.plan : 'basic',
                  });
                  if (!ok) showError('Не удалось сохранить на сервере — проверьте API и сеть');
                })()
              }
            >
              Выбрать аренду
            </Button>
          </Paper>
        </Grid>

        <Grid item xs={12} md={6}>
          <Paper sx={{ p: 3, borderRadius: 3 }}>
            <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1 }}>
              <PremiumIconBadge icon={<Dns fontSize="small" />} />
              <Typography variant="h6" sx={{ fontWeight: 700 }}>Подключение своего сервера</Typography>
            </Stack>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Подключи существующий сервер и сразу получи доступ к метрике, БД, API и тестам.
            </Typography>
            <TextField
              fullWidth
              size="small"
              label="URL вашего сервера (base URL агента), например http://1.2.3.4:3000"
              value={connectionUrl}
              onChange={(e) => setConnectionUrl(e.target.value)}
              sx={{ mb: 1.5 }}
            />
            {workspace.serverConnected && workspace.setupMode === 'connect' && workspace.agentApiKey ? (
              <Paper
                variant="outlined"
                sx={{
                  p: 1.5,
                  borderRadius: 2,
                  mb: 1.5,
                  borderColor: 'divider',
                  bgcolor: 'background.paper',
                }}
              >
                <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 0.5 }}>
                  Ключ агента (используйте как `X-Agent-Key` в heartbeat)
                </Typography>
                <Box component="code" sx={{ fontFamily: 'monospace', fontSize: 12 }}>
                  {workspace.agentApiKey}
                </Box>
              </Paper>
            ) : null}
            <Button
              variant="outlined"
              disabled={isLoading}
              onClick={() =>
                void (async () => {
                  const ok = await saveWorkspace({
                    setupMode: 'connect',
                    serverConnected: true,
                    connectionUrl: connectionUrl.trim().length > 0 ? connectionUrl.trim() : null,
                  });
                  if (!ok) showError('Не удалось сохранить на сервере — проверьте API и сеть');
                })()
              }
            >
              Подключить сервер
            </Button>
          </Paper>
        </Grid>
      </Grid>

      <Paper sx={{ p: 3, borderRadius: 3, mt: 2.5 }}>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} alignItems={{ xs: 'flex-start', sm: 'center' }}>
          <Button
            variant="contained"
            startIcon={<Science />}
            onClick={() => navigate('/dashboard/module-testing')}
          >
            Тестирование кодовых баз
          </Button>
          <Button
            variant="outlined"
            startIcon={<CheckCircle />}
            onClick={async () => {
              const ok = await saveWorkspace({ setupCompleted: true });
              if (!ok) {
                showError('Не удалось завершить настройку на сервере');
                return;
              }
              navigate('/dashboard/overview', { replace: true });
            }}
          >
            Завершить настройку и открыть кабинет
          </Button>
          {isAdmin && <Chip label="Admin: расширенные лимиты активны" color="primary" variant="outlined" />}
        </Stack>
      </Paper>
    </Box>
  );
};
