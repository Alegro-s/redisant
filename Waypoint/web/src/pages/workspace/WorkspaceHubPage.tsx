import React from 'react';
import {
  Box,
  Grid,
  Typography,
  Paper,
  Button,
  Stack,
  alpha,
  useTheme,
} from '@mui/material';
import {
  BusinessCenter,
  Code,
  QueryStats,
  Hub,
  Cable,
  CloudQueue,
  Science,
  Description,
} from '@mui/icons-material';
import { Link as RouterLink } from 'react-router-dom';
import { useCabinetMode } from '../../app/contexts/CabinetModeContext';
import { useAuth } from '../../app/contexts/AuthContext';
import { WM_CLOUD } from '../../components/layout/cloudShell';

type ZoneCard = {
  title: string;
  description: string;
  to: string;
  icon: React.ReactNode;
  primary?: boolean;
};

const ZONES: ZoneCard[] = [
  {
    title: 'Бизнес и операции',
    description: 'Документы, учёт, логистика, AI для процессов — зона менеджера.',
    to: '/dashboard/business',
    icon: <BusinessCenter sx={{ fontSize: 32 }} />,
    primary: true,
  },
  {
    title: 'Разработка и интеграции',
    description: 'Ключи ingest, Git, BaaS, SQL, тесты и Copilot — зона инженера.',
    to: '/dashboard/developer',
    icon: <Code sx={{ fontSize: 32 }} />,
    primary: true,
  },
  {
    title: 'Обзор платформы',
    description: 'Системные метрики хоста и сводка ingest в одном месте.',
    to: '/dashboard/overview',
    icon: <QueryStats sx={{ fontSize: 32 }} />,
  },
  {
    title: 'Ingest Lab',
    description: 'Таблица метрик, симуляция, квоты и проверка потока событий.',
    to: '/dashboard/ingest-lab/metrics',
    icon: <Science sx={{ fontSize: 32 }} />,
  },
  {
    title: 'WaypointMetric Hub',
    description: 'Каталог возможностей, сценарии для бизнеса и разработчиков.',
    to: '/dashboard/waypoint',
    icon: <Hub sx={{ fontSize: 32 }} />,
  },
  {
    title: 'Подключение и SDK',
    description: 'API-ключи, примеры запросов, параметры окружения.',
    to: '/dashboard/connect',
    icon: <Cable sx={{ fontSize: 32 }} />,
  },
  {
    title: 'BaaS',
    description: 'PostgreSQL-схема, REST и объекты для вашего приложения.',
    to: '/dashboard/baas',
    icon: <CloudQueue sx={{ fontSize: 32 }} />,
  },
  {
    title: 'Документы',
    description: 'Шаблоны и файлы по сделкам без привязки к 1С как к единственному UI.',
    to: '/dashboard/business/documents',
    icon: <Description sx={{ fontSize: 32 }} />,
  },
];

export const WorkspaceHubPage: React.FC = () => {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';
  const { mode, setMode } = useCabinetMode();
  const { isAdmin } = useAuth();

  return (
    <Box sx={{ maxWidth: 1200, mx: 'auto', px: { xs: 1, sm: 0 } }}>
      <Paper
        elevation={0}
        sx={{
          p: { xs: 2.5, md: 3.5 },
          mb: 3,
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
          background: isDark
            ? `linear-gradient(125deg, ${alpha(WM_CLOUD.paperElevated, 0.95)} 0%, ${alpha(WM_CLOUD.accent, 0.09)} 45%, ${alpha(WM_CLOUD.accentSecondary, 0.06)} 100%)`
            : alpha(theme.palette.primary.main, 0.06),
        }}
      >
        <Typography variant="h4" sx={{ fontWeight: 700, mb: 1, fontSize: { xs: '1.4rem', sm: '2rem' } }}>
          Рабочий стол WaypointMetric
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 720, lineHeight: 1.65, mb: 2 }}>
          Практичная среда: одна точка входа в операционку, продукт (метрики, ingest, BaaS) и витрину
          возможностей. Переключайте акцент бокового меню «бизнес / разработка» или открывайте зону напрямую.
        </Typography>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'center' }}>
          <Typography variant="caption" color="text.secondary">
            Акцент меню:
          </Typography>
          <Button
            size="small"
            variant={mode === 'business' ? 'contained' : 'outlined'}
            onClick={() => setMode('business')}
          >
            Бизнес
          </Button>
          <Button
            size="small"
            variant={mode === 'developer' ? 'contained' : 'outlined'}
            onClick={() => setMode('developer')}
          >
            Разработка
          </Button>
          {isAdmin && (
            <Typography variant="caption" color="text.secondary" sx={{ ml: { sm: 2 } }}>
              У вас расширенный доступ к инстансам и админке Lynx.
            </Typography>
          )}
        </Stack>
      </Paper>

      <Grid container spacing={2}>
        {ZONES.map((z) => (
          <Grid item xs={12} sm={6} md={4} key={z.to}>
            <Paper
              component={RouterLink}
              to={z.to}
              elevation={0}
              sx={{
                height: '100%',
                p: 2,
                textDecoration: 'none',
                color: 'inherit',
                display: 'block',
                border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
                bgcolor: isDark
                  ? z.primary
                    ? alpha(WM_CLOUD.paperElevated, 0.75)
                    : alpha(WM_CLOUD.paperElevated, 0.45)
                  : theme.palette.background.paper,
                borderRadius: 2,
                transition: 'border-color 0.2s, box-shadow 0.2s',
                '&:hover': {
                  borderColor: alpha(WM_CLOUD.accent, isDark ? 0.45 : 0.6),
                  boxShadow: `0 8px 28px ${alpha(WM_CLOUD.accent, isDark ? 0.12 : 0.18)}`,
                },
              }}
            >
              <Box sx={{ color: isDark ? WM_CLOUD.accent : theme.palette.primary.main, mb: 1 }}>{z.icon}</Box>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 0.5 }}>
                {z.title}
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.55 }}>
                {z.description}
              </Typography>
            </Paper>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
};
