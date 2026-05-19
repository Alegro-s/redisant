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
  ToggleButton,
  ToggleButtonGroup,
} from '@mui/material';
import type { Theme } from '@mui/material/styles';
import { Cloud, Group, Cloud as CloudIcon, Folder, Launch, LockOutlined, MenuBook } from '@mui/icons-material';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../app/contexts/AuthContext';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { useCabinetMode, type CabinetMode } from '../../app/contexts/CabinetModeContext';
import { PremiumIconBadge } from '../common/PremiumIconBadge';
import { DRAWER_WIDTH, RAIL_WIDTH } from './layoutConstants';
import { WM_CLOUD } from './cloudShell';
import { metricRailItems, navSectionsForMode } from './metricNavConfig';

interface SidebarProps {
  onClose?: () => void;
}

const adminExtensions = [
  { text: 'Пользователи', icon: <Group />, path: '/dashboard/users' },
  { text: 'Инстансы', icon: <CloudIcon />, path: '/dashboard/instances' },
  { text: 'Проекты', icon: <Folder />, path: '/dashboard/projects' },
];

function sectionLabelSx(theme: Theme) {
  return {
    px: 1.75,
    mb: 0.9,
    mt: 0.5,
    display: 'block',
    fontSize: '0.65rem',
    fontWeight: 600,
    letterSpacing: '0.1em',
    color: alpha(theme.palette.text.secondary, 0.85),
    textTransform: 'uppercase' as const,
  };
}

export const Sidebar: React.FC<SidebarProps> = ({ onClose }) => {
  const navigate = useNavigate();
  const location = useLocation();
  const theme = useTheme();
  const { can } = useAuth();
  const { workspace } = useWorkspace();
  const { mode, setMode } = useCabinetMode();
  const visibleSections = workspace.setupCompleted ? navSectionsForMode(mode) : [];
  const hasServerConnection = workspace.serverConnected || workspace.setupMode === 'rent' || workspace.plan === 'pro';

  const onCabinetModeChange = (_: React.MouseEvent<HTMLElement>, next: CabinetMode | null) => {
    if (!next) return;
    setMode(next);
    if (next === 'business' && location.pathname.startsWith('/dashboard/lynx-cloud')) {
      navigate('/dashboard');
      onClose?.();
    }
  };

  const handleNavigation = (path: string) => {
    navigate(path);
    onClose?.();
  };

  const navWidth = DRAWER_WIDTH - RAIL_WIDTH;
  const railBg = theme.palette.mode === 'dark' ? WM_CLOUD.sidebarRail : theme.palette.grey[200];
  const panelBg = theme.palette.mode === 'dark' ? WM_CLOUD.sidebarPanel : theme.palette.background.paper;

  return (
    <Box sx={{ display: 'flex', height: '100%', width: DRAWER_WIDTH, overflow: 'hidden' }}>
      <Box
        sx={{
          width: RAIL_WIDTH,
          flexShrink: 0,
          bgcolor: railBg,
          borderRight: `1px solid ${theme.palette.divider}`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          pt: 1.75,
          pb: 1,
          gap: 0.25,
        }}
      >
        <Tooltip title="Рабочий стол" placement="right">
          <Box
            component="button"
            type="button"
            onClick={() => handleNavigation(workspace.setupCompleted ? '/dashboard' : '/workspace/setup')}
            sx={{ border: 'none', background: 'none', cursor: 'pointer', p: 0, mb: 1, display: 'flex' }}
          >
            <Box component="img" src="/favicon.svg" alt="" sx={{ width: 26, height: 26 }} />
          </Box>
        </Tooltip>
        {metricRailItems.map((r) => {
          const active = r.match(location.pathname);
          return (
            <Tooltip key={r.path} title={r.label} placement="right">
              <IconButton
                size="medium"
                onClick={() => handleNavigation(r.path)}
                sx={{
                  borderRadius: 2,
                  minWidth: 44,
                  minHeight: 44,
                  color: active ? 'primary.main' : 'text.secondary',
                  bgcolor: active ? alpha(theme.palette.primary.main, 0.14) : 'transparent',
                }}
              >
                {r.icon}
              </IconButton>
            </Tooltip>
          );
        })}
        <Box sx={{ flexGrow: 1 }} />
        <Tooltip title="Настройка облака" placement="right">
          <IconButton
            size="medium"
            onClick={() => handleNavigation('/workspace/setup')}
            sx={{
              borderRadius: 2,
              color: location.pathname.startsWith('/workspace/setup') ? 'primary.main' : 'text.secondary',
            }}
          >
            <Cloud fontSize="small" />
          </IconButton>
        </Tooltip>
      </Box>

      <Box sx={{ width: navWidth, minWidth: 0, display: 'flex', flexDirection: 'column', bgcolor: panelBg }}>
        <Box sx={{ px: 2, pt: 2, pb: 1 }}>
          <Typography sx={{ fontWeight: 750, letterSpacing: '-0.03em', fontSize: '0.95rem' }}>Waypoint Metric</Typography>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.25, lineHeight: 1.45 }}>
            Облако: метрики, устройства, ключи. Проекты и терминал — в Desktop.
          </Typography>
          <ToggleButtonGroup
            exclusive
            value={mode}
            onChange={onCabinetModeChange}
            size="small"
            sx={{ mt: 1.25, width: '100%', '& .MuiToggleButton-root': { flex: 1, py: 0.5, fontSize: '0.72rem' } }}
          >
            <ToggleButton value="business">Стандарт</ToggleButton>
            <ToggleButton value="developer">Расширенный</ToggleButton>
          </ToggleButtonGroup>
        </Box>

        <Divider sx={{ mx: 2, borderColor: theme.palette.mode === 'dark' ? WM_CLOUD.border : undefined }} />

        <List sx={{ flexGrow: 1, px: 1.25, py: 1.25, overflowY: 'auto' }}>
          {!workspace.setupCompleted && (
            <ListItem disablePadding sx={{ mb: 0.75 }}>
              <ListItemButton
                onClick={() => handleNavigation('/workspace/setup')}
                selected={location.pathname === '/workspace/setup'}
                sx={{ borderRadius: 2, py: 1.15, px: 1.5, border: `1px solid ${alpha(theme.palette.primary.main, 0.22)}` }}
              >
                <ListItemIcon sx={{ minWidth: 40 }}>
                  <PremiumIconBadge icon={<Cloud fontSize="small" />} active={location.pathname === '/workspace/setup'} />
                </ListItemIcon>
                <ListItemText primary="Настройка облака" primaryTypographyProps={{ fontSize: '0.88rem', fontWeight: 600 }} />
              </ListItemButton>
            </ListItem>
          )}
          {visibleSections.map((section) => (
            <React.Fragment key={section.title}>
              <Typography component="span" sx={sectionLabelSx(theme)}>
                {section.title}
              </Typography>
              {section.items.map((item) => {
                const isSelected = location.pathname === item.path || location.pathname.startsWith(`${item.path}/`);
                const isLocked = !!item.requiresServer && !hasServerConnection;
                return (
                  <ListItem
                    key={`${section.title}-${item.text}`}
                    disablePadding
                    sx={{ mb: 0.35 }}
                    secondaryAction={
                      isLocked ? (
                        <Tooltip title="Подключите облако в настройке">
                          <IconButton edge="end" size="small" onClick={() => handleNavigation('/workspace/setup')}>
                            <Launch fontSize="small" />
                          </IconButton>
                        </Tooltip>
                      ) : undefined
                    }
                  >
                    <ListItemButton
                      onClick={() => handleNavigation(isLocked ? '/workspace/setup' : item.path)}
                      selected={isSelected && !isLocked}
                      sx={{
                        borderRadius: 2,
                        py: 1,
                        px: 1.5,
                        opacity: isLocked ? 0.78 : 1,
                        border: `1px solid ${isSelected && !isLocked ? alpha(theme.palette.primary.main, 0.28) : 'transparent'}`,
                        backgroundColor: isSelected && !isLocked ? alpha(theme.palette.primary.main, 0.1) : 'transparent',
                      }}
                    >
                      <ListItemIcon sx={{ minWidth: 38 }}>
                        <PremiumIconBadge
                          icon={isLocked ? <LockOutlined sx={{ fontSize: 18 }} /> : item.icon}
                          active={isSelected && !isLocked}
                          size={28}
                        />
                      </ListItemIcon>
                      <ListItemText
                        primary={item.text}
                        secondary={isLocked ? 'Нужен сервер' : item.secondary}
                        primaryTypographyProps={{ fontWeight: isSelected && !isLocked ? 600 : 450, fontSize: '0.86rem' }}
                        secondaryTypographyProps={{ sx: { mt: 0.15, fontSize: '0.68rem' } }}
                      />
                    </ListItemButton>
                  </ListItem>
                );
              })}
            </React.Fragment>
          ))}
          {workspace.setupCompleted && !hasServerConnection && mode === 'developer' && (
            <Box sx={{ px: 1.75, pt: 1 }}>
              <Typography variant="caption" color="text.secondary" sx={{ lineHeight: 1.45 }}>
                Разделы «Инфраструктура» доступны после подключения сервера.
              </Typography>
            </Box>
          )}
          {can('users:manage') && workspace.setupCompleted && (
            <>
              <Divider sx={{ my: 1.25 }} />
              <Typography component="span" sx={sectionLabelSx(theme)}>
                Админ
              </Typography>
              {adminExtensions.map((item) => {
                const isSelected = location.pathname === item.path || location.pathname.startsWith(`${item.path}/`);
                return (
                  <ListItem key={item.text} disablePadding sx={{ mb: 0.35 }}>
                    <ListItemButton onClick={() => handleNavigation(item.path)} selected={isSelected} sx={{ borderRadius: 2, py: 1, px: 1.5 }}>
                      <ListItemIcon sx={{ minWidth: 38 }}>
                        <PremiumIconBadge icon={item.icon} active={isSelected} size={28} />
                      </ListItemIcon>
                      <ListItemText primary={item.text} primaryTypographyProps={{ fontSize: '0.86rem' }} />
                    </ListItemButton>
                  </ListItem>
                );
              })}
            </>
          )}
        </List>

        <Divider sx={{ mx: 2 }} />
        <Box sx={{ p: 1.5 }}>
          <ListItemButton component="a" href="/metric/docs" sx={{ borderRadius: 2, py: 0.85, mb: 1 }}>
            <ListItemIcon sx={{ minWidth: 36 }}>
              <MenuBook fontSize="small" color="primary" />
            </ListItemIcon>
            <ListItemText primary="Документация" primaryTypographyProps={{ fontSize: '0.82rem', fontWeight: 600 }} />
          </ListItemButton>
          <Box sx={{ display: 'flex', justifyContent: 'center' }}>
            <Chip
              size="small"
              label={workspace.plan === 'pro' ? 'План Pro' : 'План Basic'}
              color={workspace.plan === 'pro' ? 'primary' : 'default'}
              variant={workspace.plan === 'pro' ? 'filled' : 'outlined'}
            />
          </Box>
        </Box>
      </Box>
    </Box>
  );
};
