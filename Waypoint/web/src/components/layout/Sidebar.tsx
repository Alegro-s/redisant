import React from 'react';
import {
  Box,
  List,
  ListItem,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Typography,
  Divider,
  alpha,
  useTheme,
  Chip,
  Tooltip,
  IconButton,
} from '@mui/material';
import type { Theme } from '@mui/material/styles';
import { Cloud, Group, Cloud as CloudIcon, Launch, LockOutlined, MenuBook } from '@mui/icons-material';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../app/contexts/AuthContext';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { DRAWER_WIDTH } from './layoutConstants';
import { WM_CLOUD } from './cloudShell';
import { navSectionsForMode } from './metricNavConfig';

interface SidebarProps {
  onClose?: () => void;
}

const adminExtensions = [
  { text: 'Пользователи', icon: <Group />, path: '/dashboard/users' },
  { text: 'Инстансы', icon: <CloudIcon />, path: '/dashboard/instances' },
];

function sectionLabelSx(theme: Theme) {
  return {
    px: 2,
    mb: 0.75,
    mt: 1.25,
    display: 'block',
    fontSize: '0.62rem',
    fontWeight: 700,
    letterSpacing: '0.14em',
    color: alpha(theme.palette.text.secondary, 0.75),
    textTransform: 'uppercase' as const,
  };
}

function navButtonSx(theme: Theme, selected: boolean) {
  return {
    borderRadius: 2.5,
    py: 1.05,
    pl: selected ? 2.25 : 2,
    pr: 1.5,
    mb: 0.2,
    transition: 'background-color 0.18s ease, color 0.18s ease',
    bgcolor: selected ? alpha(theme.palette.primary.main, 0.11) : 'transparent',
    color: selected ? 'text.primary' : 'text.secondary',
    '&:hover': {
      bgcolor: alpha(theme.palette.primary.main, selected ? 0.14 : 0.07),
    },
    '&.Mui-selected': {
      bgcolor: alpha(theme.palette.primary.main, 0.11),
      '&:hover': { bgcolor: alpha(theme.palette.primary.main, 0.14) },
    },
    '&.Mui-selected::before': {
      content: '""',
      position: 'absolute',
      left: 6,
      top: '22%',
      bottom: '22%',
      width: 3,
      borderRadius: 4,
      bgcolor: 'primary.main',
    },
  };
}

export const Sidebar: React.FC<SidebarProps> = ({ onClose }) => {
  const navigate = useNavigate();
  const location = useLocation();
  const theme = useTheme();
  const { can } = useAuth();
  const { workspace } = useWorkspace();
  const visibleSections = workspace.setupCompleted ? navSectionsForMode('business') : [];
  const hasServerConnection = workspace.serverConnected || workspace.setupMode === 'rent' || workspace.plan === 'pro';

  const panelBg =
    theme.palette.mode === 'dark' ? WM_CLOUD.sidebar : theme.palette.background.paper;

  const handleNavigation = (path: string) => {
    navigate(path);
    onClose?.();
  };

  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        width: DRAWER_WIDTH,
        bgcolor: panelBg,
        backgroundImage:
          theme.palette.mode === 'dark'
            ? `linear-gradient(180deg, ${alpha(theme.palette.primary.main, 0.06)} 0%, transparent 28%)`
            : 'none',
      }}
    >
      <Box sx={{ px: 2.25, pt: 2.25, pb: 1.5 }}>
        <Box
          component="button"
          type="button"
          onClick={() =>
            handleNavigation(workspace.setupCompleted ? '/dashboard' : '/workspace/setup')
          }
          sx={{
            border: 'none',
            background: 'none',
            cursor: 'pointer',
            p: 0,
            display: 'flex',
            alignItems: 'center',
            gap: 1.25,
            textAlign: 'left',
            color: 'inherit',
            width: '100%',
          }}
        >
          <Box
            component="img"
            src="/favicon.svg"
            alt=""
            sx={{
              width: 32,
              height: 32,
              borderRadius: 2,
              boxShadow: `0 0 0 1px ${alpha(theme.palette.primary.main, 0.25)}`,
            }}
          />
          <Box sx={{ minWidth: 0 }}>
            <Typography
              sx={{
                fontWeight: 800,
                letterSpacing: '-0.04em',
                fontSize: '1rem',
                lineHeight: 1.15,
              }}
            >
              Waypoint Metric
            </Typography>
            <Typography
              variant="caption"
              color="text.secondary"
              sx={{ display: 'block', mt: 0.2, lineHeight: 1.35, fontSize: '0.7rem' }}
            >
              Облако · Desktop на ПК
            </Typography>
          </Box>
        </Box>
      </Box>

      <Divider sx={{ mx: 2, opacity: 0.7 }} />

      <List sx={{ flexGrow: 1, px: 1.5, py: 1.25, overflowY: 'auto' }}>
        {!workspace.setupCompleted && (
          <ListItem disablePadding sx={{ mb: 0.5 }}>
            <ListItemButton
              onClick={() => handleNavigation('/workspace/setup')}
              selected={location.pathname === '/workspace/setup'}
              sx={{
                ...navButtonSx(theme, location.pathname === '/workspace/setup'),
                border: `1px dashed ${alpha(theme.palette.primary.main, 0.35)}`,
              }}
            >
              <ListItemIcon sx={{ minWidth: 36, color: 'primary.main' }}>
                <Cloud fontSize="small" />
              </ListItemIcon>
              <ListItemText
                primary="Настройка облака"
                primaryTypographyProps={{ fontSize: '0.875rem', fontWeight: 650 }}
              />
            </ListItemButton>
          </ListItem>
        )}

        {visibleSections.map((section) => (
          <React.Fragment key={section.title}>
            <Typography component="span" sx={sectionLabelSx(theme)}>
              {section.title}
            </Typography>
            {section.items.map((item) => {
              const isSelected =
                location.pathname === item.path ||
                location.pathname.startsWith(`${item.path}/`);
              const isLocked = !!item.requiresServer && !hasServerConnection;
              return (
                <ListItem
                  key={`${section.title}-${item.text}`}
                  disablePadding
                  secondaryAction={
                    isLocked ? (
                      <Tooltip title="Сначала настройте облако">
                        <IconButton
                          edge="end"
                          size="small"
                          onClick={() => handleNavigation('/workspace/setup')}
                        >
                          <Launch sx={{ fontSize: 16 }} />
                        </IconButton>
                      </Tooltip>
                    ) : undefined
                  }
                >
                  <ListItemButton
                    onClick={() =>
                      handleNavigation(isLocked ? '/workspace/setup' : item.path)
                    }
                    selected={isSelected && !isLocked}
                    sx={{
                      ...navButtonSx(theme, isSelected && !isLocked),
                      opacity: isLocked ? 0.65 : 1,
                    }}
                  >
                    <ListItemIcon
                      sx={{
                        minWidth: 36,
                        color: isSelected && !isLocked ? 'primary.main' : 'inherit',
                      }}
                    >
                      {isLocked ? (
                        <LockOutlined sx={{ fontSize: 20 }} />
                      ) : (
                        item.icon
                      )}
                    </ListItemIcon>
                    <ListItemText
                      primary={item.text}
                      secondary={isLocked ? 'Нужно облако' : item.secondary}
                      primaryTypographyProps={{
                        fontWeight: isSelected && !isLocked ? 650 : 500,
                        fontSize: '0.875rem',
                      }}
                      secondaryTypographyProps={{ sx: { mt: 0.1, fontSize: '0.68rem' } }}
                    />
                  </ListItemButton>
                </ListItem>
              );
            })}
          </React.Fragment>
        ))}

        {can('users:manage') && workspace.setupCompleted && (
          <>
            <Divider sx={{ my: 1.5, mx: 0.5 }} />
            <Typography component="span" sx={sectionLabelSx(theme)}>
              Администрирование
            </Typography>
            {adminExtensions.map((item) => {
              const isSelected =
                location.pathname === item.path ||
                location.pathname.startsWith(`${item.path}/`);
              return (
                <ListItem key={item.text} disablePadding>
                  <ListItemButton
                    onClick={() => handleNavigation(item.path)}
                    selected={isSelected}
                    sx={navButtonSx(theme, isSelected)}
                  >
                    <ListItemIcon sx={{ minWidth: 36 }}>{item.icon}</ListItemIcon>
                    <ListItemText
                      primary={item.text}
                      primaryTypographyProps={{ fontSize: '0.875rem', fontWeight: 500 }}
                    />
                  </ListItemButton>
                </ListItem>
              );
            })}
          </>
        )}
      </List>

      <Box
        sx={{
          p: 2,
          pt: 1.5,
          borderTop: `1px solid ${theme.palette.divider}`,
          background:
            theme.palette.mode === 'dark'
              ? alpha(WM_CLOUD.paperElevated, 0.55)
              : alpha(theme.palette.grey[100], 0.8),
        }}
      >
        <ListItemButton
          component="a"
          href="/metric/docs"
          sx={{ borderRadius: 2, py: 0.9, px: 1.25, mb: 1.25 }}
        >
          <ListItemIcon sx={{ minWidth: 34 }}>
            <MenuBook fontSize="small" color="primary" />
          </ListItemIcon>
          <ListItemText
            primary="Документация"
            primaryTypographyProps={{ fontSize: '0.82rem', fontWeight: 600 }}
          />
        </ListItemButton>
        <Box sx={{ display: 'flex', justifyContent: 'center' }}>
          <Chip
            size="small"
            label={workspace.plan === 'pro' ? 'План Pro' : 'План Basic'}
            color={workspace.plan === 'pro' ? 'primary' : 'default'}
            variant={workspace.plan === 'pro' ? 'filled' : 'outlined'}
            sx={{ fontWeight: 600, letterSpacing: '0.02em' }}
          />
        </Box>
      </Box>
    </Box>
  );
};
