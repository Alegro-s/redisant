import React from 'react';
import { Box, Typography, alpha, useTheme } from '@mui/material';
import { Outlet } from 'react-router-dom';
import { PageSubNav } from '../../components/layout/PageSubNav';
import { WM_CLOUD } from '../../components/layout/cloudShell';

const NAV = [
  { label: 'Каталог', to: '/dashboard/waypoint' },
  { label: 'Ingest Lab', to: '/dashboard/ingest-lab/metrics' },
  { label: 'Ассистент', to: '/dashboard/waypoint/assistant' },
];

export const WaypointLayout: React.FC = () => {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';

  return (
    <Box sx={{ px: { xs: 0, sm: 1 }, py: { xs: 1, sm: 2 }, maxWidth: 1200, mx: 'auto' }}>
      <Box
        sx={{
          borderRadius: 3,
          p: { xs: 2, sm: 2.5 },
          mb: 2,
          background: isDark ? alpha(WM_CLOUD.paperElevated, 0.9) : alpha(theme.palette.primary.main, 0.04),
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
        }}
      >
        <Typography variant="h5" sx={{ fontWeight: 700, letterSpacing: '-0.02em', mb: 0.5 }}>
          Waypoint Metric
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 640, lineHeight: 1.55 }}>
          Каталог возможностей и сценарии. Ежедневная работа — в разделах слева: метрики, ingest, устройства.
        </Typography>
      </Box>
      <PageSubNav items={NAV} />
      <Box sx={{ mt: 2 }}>
        <Outlet />
      </Box>
    </Box>
  );
};
