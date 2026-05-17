import React from 'react';
import { Box, Typography } from '@mui/material';
import { Outlet } from 'react-router-dom';
import { PageSubNav } from '../../components/layout/PageSubNav';
import { LYNX_CLOUD_DASH } from '../../constants/lynxRoutes';

const LYNX_CLOUD_SUB = [
  { label: 'Проекты', to: `${LYNX_CLOUD_DASH}/projects` },
  { label: 'Ядро Lynx', to: `${LYNX_CLOUD_DASH}/engine` },
  { label: 'Сборки', to: `${LYNX_CLOUD_DASH}/builds` },
  { label: 'Коммерция', to: `${LYNX_CLOUD_DASH}/commercial` },
];

export const NexusCloudLayout: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" gutterBottom>
        Lynx Cloud
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Личный кабинет разработчика на том же API, что и WaypointMetric (lynx-cloud.ru). Проекты, релизы ядра, очередь
        сборок. Публичный маркетинг — на lynx-hub.ru.
      </Typography>
      <PageSubNav items={LYNX_CLOUD_SUB} />
      <Outlet />
    </Box>
  );
};
