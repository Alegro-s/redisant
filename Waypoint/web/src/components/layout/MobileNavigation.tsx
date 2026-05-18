import React from 'react';
import { Box, Paper, Typography, useTheme } from '@mui/material';
import { Storage } from '@mui/icons-material';
import { useNavigate, useLocation } from 'react-router-dom';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { useCabinetMode } from '../../app/contexts/CabinetModeContext';
import { mobileNavForMode } from './metricNavConfig';

export const MOBILE_NAV_HEIGHT = 64;

export const MobileNavigation: React.FC = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { workspace } = useWorkspace();
  const { mode } = useCabinetMode();
  const theme = useTheme();

  const navigation = !workspace.setupCompleted
    ? [{ label: 'Setup', icon: <Storage />, path: '/workspace/setup' }]
    : mobileNavForMode(mode);

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
        bgcolor: 'background.paper',
        pb: 'env(safe-area-inset-bottom, 0px)',
      }}
    >
      <Box
        sx={{
          display: 'flex',
          justifyContent: 'space-around',
          alignItems: 'stretch',
          px: 0.5,
          py: 0.5,
          gap: 0.25,
        }}
      >
        {navigation.map((item) => {
          const active =
            item.path === '/dashboard'
              ? location.pathname === '/dashboard'
              : location.pathname === item.path || location.pathname.startsWith(`${item.path}/`);
          return (
            <Box
              key={item.path}
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
                flex: 1,
                minWidth: 0,
                px: 0.5,
                py: 0.5,
                borderRadius: 2,
                textAlign: 'center',
                cursor: 'pointer',
                bgcolor: active ? theme.palette.action.selected : 'transparent',
                '&:active': { opacity: 0.85 },
              }}
            >
              <Box sx={{ color: active ? 'primary.main' : 'text.secondary', display: 'flex', justifyContent: 'center', '& svg': { fontSize: 22 } }}>
                {item.icon}
              </Box>
              <Typography
                variant="caption"
                sx={{
                  display: 'block',
                  mt: 0.25,
                  fontSize: '0.62rem',
                  fontWeight: active ? 700 : 500,
                  lineHeight: 1.1,
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
