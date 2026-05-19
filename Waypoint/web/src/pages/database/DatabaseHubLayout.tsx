import React from 'react';
import { Alert, Box, CircularProgress, Typography } from '@mui/material';
import { Outlet } from 'react-router-dom';
import { PageSubNav } from '../../components/layout/PageSubNav';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { BaasConsoleProvider, useBaasConsole } from '../baas/BaasConsoleContext';
import { DATABASE_HUB_NAV } from './databaseHubNav';
import { DatabaseEnvironmentBar } from './DatabaseEnvironmentBar';

function DatabaseHubInner() {
  const { workspace } = useWorkspace();
  const { loading, schemaName } = useBaasConsole();
  const hasServer = workspace.serverConnected || workspace.setupMode === 'rent' || workspace.plan === 'pro';

  return (
    <Box sx={{ maxWidth: 1200, mx: 'auto' }}>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 0.5 }}>
        База данных
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2, maxWidth: 720, lineHeight: 1.6 }}>
        Таблицы, схема связей, запросы и файлы — в облаке. Проекты на своём компьютере — в Waypoint Desktop.
      </Typography>

      {!hasServer && (
        <Alert severity="info" sx={{ mb: 2 }}>
          Сначала подключите облако в{' '}
          <a href="/workspace/setup" style={{ color: 'inherit', fontWeight: 600 }}>
            настройке
          </a>
          — тогда можно создавать таблицы. Раздел «Ключи» доступен уже сейчас.
        </Alert>
      )}

      {hasServer && !schemaName && !loading && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          База ещё готовится. Нажмите «Включить аренду» в настройке или подождите минуту и обновите страницу.
        </Alert>
      )}

      {loading && (
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
          <CircularProgress size={18} />
          <Typography variant="body2">Загрузка схемы…</Typography>
        </Box>
      )}

      {schemaName ? (
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1 }}>
          Подпроект: <strong>{schemaName}</strong>
        </Typography>
      ) : null}

      <DatabaseEnvironmentBar />
      <PageSubNav items={[...DATABASE_HUB_NAV]} />
      <Outlet />
    </Box>
  );
}

export const DatabaseHubLayout: React.FC = () => (
  <BaasConsoleProvider>
    <DatabaseHubInner />
  </BaasConsoleProvider>
);
