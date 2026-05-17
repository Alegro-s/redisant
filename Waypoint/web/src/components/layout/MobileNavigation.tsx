import React from 'react';
import { Box, Paper, Typography, useTheme } from '@mui/material';
import {
  Dashboard,
  Source,
  QueryStats,
  Science,
  Storage,
  TableChart,
  Group,
  SmartToy,
  Code,
  AccountBalanceWallet,
  Settings,
  Hub,
  Description,
  CloudQueue,
  HomeWork,
} from '@mui/icons-material';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../app/contexts/AuthContext';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { useCabinetMode } from '../../app/contexts/CabinetModeContext';


export const MOBILE_NAV_HEIGHT = 72;

export const MobileNavigation: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { can } = useAuth();
  const { workspace } = useWorkspace();
  const { mode } = useCabinetMode();
  const theme = useTheme();

  const navigation = !workspace.setupCompleted
    ? [{ label: 'Setup', icon: <Storage />, path: '/workspace/setup' }]
    : mode === 'business'
    ? [
        { label: 'Стол', icon: <HomeWork />, path: '/dashboard' },
        { label: 'Бизнес', icon: <Dashboard />, path: '/dashboard/business' },
        { label: 'AI', icon: <SmartToy />, path: '/dashboard/business/ai' },
        { label: 'Сводки', icon: <QueryStats />, path: '/dashboard/ingest-lab/summary' },
        { label: 'Hub', icon: <Hub />, path: '/dashboard/waypoint' },
        { label: 'Документы', icon: <Description />, path: '/dashboard/business/documents' },
        { label: 'Баланс', icon: <AccountBalanceWallet />, path: '/dashboard/billing' },
        { label: 'Настройки', icon: <Settings />, path: '/dashboard/settings' },
      ]
    : can('users:manage')
    ? [
        { label: 'Стол', icon: <HomeWork />, path: '/dashboard' },
        { label: 'Dev', icon: <Code />, path: '/dashboard/developer' },
        { label: 'Copilot', icon: <SmartToy />, path: '/dashboard/developer/ai' },
        { label: 'Git', icon: <Source />, path: '/dashboard/git' },
        { label: 'Ingest', icon: <QueryStats />, path: '/dashboard/ingest-lab' },
        { label: 'SQL', icon: <TableChart />, path: '/dashboard/database' },
        { label: 'BaaS', icon: <CloudQueue />, path: '/dashboard/baas' },
        { label: 'Тесты', icon: <Science />, path: '/dashboard/module-testing' },
        { label: 'Юзеры', icon: <Group />, path: '/dashboard/users' },
        { label: 'Настройки', icon: <Settings />, path: '/dashboard/settings' },
      ]
    : [
        { label: 'Стол', icon: <HomeWork />, path: '/dashboard' },
        { label: 'Dev', icon: <Code />, path: '/dashboard/developer' },
        { label: 'Copilot', icon: <SmartToy />, path: '/dashboard/developer/ai' },
        { label: 'Git', icon: <Source />, path: '/dashboard/git' },
        { label: 'Ingest', icon: <QueryStats />, path: '/dashboard/ingest-lab' },
        { label: 'Тесты', icon: <Science />, path: '/dashboard/module-testing' },
        { label: 'SQL', icon: <TableChart />, path: '/dashboard/database' },
        { label: 'Настройки', icon: <Settings />, path: '/dashboard/settings' },
      ];

  return (
    <Paper
      square
      elevation={8}
      sx={{
        position: 'fixed',
        bottom: 0,
        left: 0,
        right: 0,
        zIndex: 1000,
        display: { xs: 'block', sm: 'none' },
        borderRadius: 0,
        borderTop: 1,
        borderColor: 'divider',
        bgcolor: theme.palette.mode === 'dark' ? 'background.paper' : theme.palette.background.paper,
        pb: 'env(safe-area-inset-bottom, 0px)',
      }}
    >
      <Box
        sx={{
          display: 'flex',
          overflowX: 'auto',
          overflowY: 'hidden',
          gap: 0.25,
          px: 0.75,
          py: 0.75,
          alignItems: 'stretch',
          scrollSnapType: 'x proximity',
          WebkitOverflowScrolling: 'touch',
          '&::-webkit-scrollbar': { display: 'none' },
          scrollbarWidth: 'none',
        }}
      >
        {navigation.map((item) => {
          const active =
            item.path === '/dashboard'
              ? location.pathname === '/dashboard'
              : location.pathname === item.path || location.pathname.startsWith(`${item.path}/`);
          return (
            <Box
              key={`${item.path}-${item.label}`}
              onClick={() => navigate(item.path)}
              role="button"
              tabIndex={0}
              onKeyDown={(e) => {
                if (e.key === 'Enter' || e.key === ' ') {
                  e.preventDefault();
                  navigate(item.path);
                }
              }}
              sx={{
                flex: '0 0 auto',
                scrollSnapAlign: 'start',
                minWidth: 68,
                maxWidth: 92,
                px: 0.75,
                py: 0.5,
                borderRadius: 2,
                textAlign: 'center',
                cursor: 'pointer',
                bgcolor: active ? theme.palette.action.selected : 'transparent',
                border: `1px solid ${active ? theme.palette.primary.main + '55' : 'transparent'}`,
                '&:active': { opacity: 0.85 },
              }}
            >
              <Box
                sx={{
                  color: active ? 'primary.main' : 'text.secondary',
                  display: 'flex',
                  justifyContent: 'center',
                  '& svg': { fontSize: 24 },
                }}
              >
                {item.icon}
              </Box>
              <Typography
                variant="caption"
                sx={{
                  display: 'block',
                  mt: 0.35,
                  fontSize: '0.62rem',
                  fontWeight: active ? 700 : 500,
                  lineHeight: 1.15,
                  color: active ? 'primary.main' : 'text.secondary',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                }}
              >
                {item.label}
              </Typography>
            </Box>
          );
        })}
      </Box>
    </Paper>
  );
};
