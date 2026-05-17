import React from 'react';
import { Alert, Box, CircularProgress, Typography } from '@mui/material';
import { Outlet } from 'react-router-dom';
import { PageSubNav } from '../../components/layout/PageSubNav';
import { useBaasConsole } from './BaasConsoleContext';

const BAAS_SUB = [
  { label: 'SQL', to: '/dashboard/baas/sql' },
  { label: 'REST', to: '/dashboard/baas/rest' },
  { label: 'Storage', to: '/dashboard/baas/storage' },
  { label: 'AI', to: '/dashboard/baas/ai' },
];

export const BaasLayout: React.FC = () => {
  const { loading, schemaName } = useBaasConsole();

  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        BaaS Console
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        SQL, REST, S3-совместимое хранилище и AI-чат через Waypoint (DeepSeek).
      </Typography>

      <PageSubNav items={BAAS_SUB} />

      {!schemaName && (
        <Alert severity="warning" sx={{ mb: 2 }}>
          BaaS не инициализирован на сервере (WM_BAAS_ENABLED / WM_BAAS_SCHEMA). Кнопки ниже могут не
          работать.
        </Alert>
      )}

      {loading && (
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 2 }}>
          <CircularProgress size={18} />
          <Typography variant="body2">Загрузка…</Typography>
        </Box>
      )}

      <Outlet />
    </Box>
  );
};
