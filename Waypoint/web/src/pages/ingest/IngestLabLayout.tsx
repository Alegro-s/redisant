import React from 'react';
import { Link as RouterLink, Outlet } from 'react-router-dom';
import { Box, Typography, Button } from '@mui/material';
import { PageSubNav } from '../../components/layout/PageSubNav';

const subNavItems = [
  { label: 'Сводка', to: '/dashboard/ingest-lab/summary' },
  { label: 'Поток', to: '/dashboard/ingest-lab/metrics' },
  { label: 'Журнал', to: '/dashboard/ingest-lab/logs' },
  { label: 'Ключи', to: '/dashboard/ingest-lab/keys-usage' },
];

export const IngestLabLayout: React.FC = () => {
  return (
    <Box sx={{ px: { xs: 0, sm: 1 }, py: { xs: 1, sm: 2 }, maxWidth: 1100, mx: 'auto' }}>
      <Box sx={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 1, mb: 1.5 }}>
        <Typography variant="h5" sx={{ fontWeight: 700, letterSpacing: '-0.02em', flex: '1 1 auto' }}>
          Метрики
        </Typography>
        <Button component={RouterLink} to="/dashboard/business/ai" variant="outlined" size="small">
          Помощник
        </Button>
        <Button component={RouterLink} to="/dashboard/settings/devices" variant="text" size="small">
          Устройства Desktop
        </Button>
      </Box>
      <PageSubNav items={subNavItems} />
      <Outlet />
    </Box>
  );
};
