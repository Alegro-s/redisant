import React from 'react';
import { Box, Button, Stack, Typography, alpha, useTheme } from '@mui/material';
import { Link as RouterLink, Outlet } from 'react-router-dom';
import { Business, Code } from '@mui/icons-material';
import { PageSubNav } from '../../components/layout/PageSubNav';
import { WM_CLOUD } from '../../components/layout/cloudShell';

const NAV = [
  { label: 'Обзор', to: '/dashboard/waypoint' },
  { label: 'Кабинет · бизнес', to: '/dashboard/business' },
  { label: 'Кабинет · разработка', to: '/dashboard/developer' },
  { label: 'Каталог · бизнес', to: '/dashboard/waypoint/business' },
  { label: 'Каталог · разработчики', to: '/dashboard/waypoint/developers' },
  { label: 'AI · бизнес', to: '/dashboard/business/ai' },
  { label: 'Ingest Lab', to: '/dashboard/ingest-lab/metrics' },
];

export const WaypointLayout: React.FC = () => {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';

  return (
    <Box
      sx={{
        px: { xs: 2, sm: 3 },
        py: { xs: 2, sm: 3 },
        maxWidth: 1280,
        mx: 'auto',
        minHeight: '70vh',
      }}
    >
      <Box
        sx={{
          borderRadius: 4,
          p: { xs: 2.5, sm: 3 },
          mb: 2.5,
          background: isDark
            ? `linear-gradient(145deg, ${alpha(WM_CLOUD.paperElevated, 0.95)} 0%, ${alpha(WM_CLOUD.canvas, 0.5)} 100%)`
            : alpha(theme.palette.primary.main, 0.04),
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
          boxShadow: isDark ? '0 24px 80px rgba(0,0,0,0.25)' : '0 8px 40px rgba(0,0,0,0.06)',
        }}
      >
        <Typography
          variant="h4"
          sx={{
            fontWeight: 800,
            letterSpacing: '-0.02em',
            mb: 0.5,
            background: isDark
              ? `linear-gradient(90deg, #fff 0%, ${WM_CLOUD.accent} 120%)`
              : theme.palette.text.primary,
            backgroundClip: isDark ? 'text' : undefined,
            WebkitBackgroundClip: isDark ? 'text' : undefined,
            WebkitTextFillColor: isDark ? 'transparent' : undefined,
          }}
        >
          WaypointMetric
        </Typography>
        <Typography variant="body1" color="text.secondary" sx={{ maxWidth: 720, lineHeight: 1.65 }}>
          Метрики, ingest, BaaS и AI на одном API. Сначала выберите режим кабинета — <strong>бизнес</strong> (операции,
          документы, логистика) или <strong>разработка</strong> (облако, БД, Copilot). Здесь — обзор и каталог услуг;
          ежедневная работа — в соответствующих разделах слева.
        </Typography>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.25} sx={{ mt: 2 }}>
          <Button
            size="medium"
            variant="contained"
            component={RouterLink}
            to="/dashboard/business"
            startIcon={<Business />}
            sx={{ fontWeight: 700, borderRadius: 2 }}
          >
            Режим «Бизнес»
          </Button>
          <Button
            size="medium"
            variant="outlined"
            component={RouterLink}
            to="/dashboard/developer"
            startIcon={<Code />}
            sx={{ fontWeight: 700, borderRadius: 2 }}
          >
            Режим «Разработка»
          </Button>
        </Stack>
      </Box>
      <PageSubNav items={NAV} />
      <Box sx={{ mt: 3 }}>
        <Outlet />
      </Box>
    </Box>
  );
};
