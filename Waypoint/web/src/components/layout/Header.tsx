import React, { useState } from 'react';
import {
  AppBar,
  Toolbar,
  IconButton,
  Typography,
  Badge,
  Avatar,
  Menu,
  MenuItem,
  Box,
  InputBase,
  alpha,
  useTheme,
  Button,
  Link,
  ToggleButton,
  ToggleButtonGroup,
  Drawer,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Divider,
  useMediaQuery,
} from '@mui/material';
import { GlobalSearch } from './GlobalSearch';
import {
  Menu as MenuIcon,
  Search,
  Notifications,
  Brightness4,
  Brightness7,
  AccountCircle,
  Logout,
  Help,
  MenuBook,
  Layers,
  Settings,
  AccountBalanceWallet,
  Close,
} from '@mui/icons-material';
import { useNavigate, useLocation, Link as RouterLink } from 'react-router-dom';
import { useThemeContext } from '../../app/contexts/ThemeContext';
import { useAuth } from '../../app/contexts/AuthContext';
import { useCabinetMode, type CabinetMode } from '../../app/contexts/CabinetModeContext';
import { PwaInstallButton } from '../common/PwaInstallButton';
import { WM_CLOUD } from './cloudShell';

interface HeaderProps {
  onMenuClick: () => void;
}

export const Header: React.FC<HeaderProps> = ({ onMenuClick }) => {
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const [accountDrawerOpen, setAccountDrawerOpen] = useState(false);
  const [notificationAnchor, setNotificationAnchor] = useState<null | HTMLElement>(null);
  const navigate = useNavigate();
  const location = useLocation();
  const { mode, toggleTheme } = useThemeContext();
  const { user, logout } = useAuth();
  const theme = useTheme();
  const { mode: cabinetMode, setMode: setCabinetMode } = useCabinetMode();
  const accountInDrawer = useMediaQuery(theme.breakpoints.down('lg'));

  const getPageTitle = () => {
    const path = location.pathname;
    if (path === '/workspace/setup' || path === '/dashboard/onboarding') return 'Настройка облака';
    if (path === '/dashboard') return 'Рабочий стол';
    if (path.startsWith('/dashboard/business/ai')) return 'Помощник';
    if (path.startsWith('/dashboard/settings/devices')) return 'Waypoint Desktop';
    if (path === '/dashboard/developer') return 'Сервер · инфраструктура';
    if (path.startsWith('/dashboard/developer/ai')) return 'Помощник';
    if (path === '/dashboard/overview') return 'Обзор';
    if (path === '/dashboard/git') return 'Git';
    if (path === '/dashboard/graphics') return 'Графика';
    if (path === '/dashboard/api') return 'API';
    if (path === '/dashboard/realtime') return 'Realtime';
    if (path === '/dashboard/users') return 'Пользователи';
    if (path === '/dashboard/projects') return 'Проекты';
    if (path === '/dashboard/assets') return 'Ассеты';
    if (path.startsWith('/dashboard/database')) return 'База данных';
    if (path === '/dashboard/logs') return 'Логи сервера';
    if (path === '/dashboard/instances') return 'Инстансы Waypoint';
    if (path === '/dashboard/jobs') return 'Задания';
    if (path === '/dashboard/versions') return 'Ядро Lynx (редирект)';
    if (path.startsWith('/dashboard/lynx-cloud/engine')) return 'Ядро Lynx';
    if (path === '/dashboard/ai') return 'ИИ (анализ)';
    if (path === '/dashboard/settings') return 'Настройки';
    if (path.startsWith('/dashboard/waypoint')) return 'Обзор';
    if (path.startsWith('/dashboard/ingest-lab')) return 'Метрики';
    if (path.startsWith('/dashboard/baas')) return 'BaaS';
    if (path.startsWith('/dashboard/lynx-cloud')) return 'Lynx Cloud';
    if (path.startsWith('/dashboard/nexus-cloud')) return 'Lynx Cloud';
    if (path === '/dashboard/billing') return 'Баланс и платежи';
    if (path === '/dashboard/connect') return 'Подключение и SDK';
    if (path === '/dashboard/registration-log') return 'Журнал регистраций';
    return 'WaypointMetric';
  };

  const homePath = '/dashboard';
  const onCabinetModeChange = (_: React.MouseEvent<HTMLElement>, next: CabinetMode | null) => {
    if (!next) return;
    setCabinetMode(next);
    if (next === 'business' && location.pathname.startsWith('/dashboard/lynx-cloud')) navigate('/dashboard');
    if (next === 'developer' && location.pathname === '/dashboard') navigate('/dashboard/lynx-cloud');
  };

  const closeAccountUi = () => {
    setAnchorEl(null);
    setAccountDrawerOpen(false);
  };

  const handleLogout = () => {
    logout();
    navigate('/login');
    closeAccountUi();
  };

  const openAccountPanel = (e: React.MouseEvent<HTMLElement>) => {
    if (accountInDrawer) setAccountDrawerOpen(true);
    else setAnchorEl(e.currentTarget);
  };

  const headerBg = theme.palette.mode === 'dark' ? WM_CLOUD.header : alpha(theme.palette.background.paper, 0.92);

  return (
    <AppBar
      position="fixed"
      elevation={0}
      sx={{
        width: '100%',
        left: 0,
        zIndex: (t) => t.zIndex.drawer + 1,
        bgcolor: headerBg,
        borderBottom: `1px solid ${theme.palette.divider}`,
        boxShadow: 'none',
      }}
    >
      <Toolbar sx={{ px: { xs: 1, sm: 2 } }}>
        <IconButton
          color="inherit"
          edge="start"
          onClick={onMenuClick}
          sx={{ mr: 1.5, display: { sm: 'none' } }}
          aria-label="Открыть меню"
        >
          <MenuIcon />
        </IconButton>

        <Box
          component={RouterLink}
          to={homePath}
          sx={{
            display: 'flex',
            alignItems: 'center',
            gap: 1.25,
            textDecoration: 'none',
            color: 'inherit',
            mr: 2,
            flexShrink: 0,
          }}
        >
          <Box component="img" src="/favicon.svg" alt="" sx={{ width: 28, height: 28, display: 'block' }} />
          <Typography
            variant="h6"
            noWrap
            sx={{
              fontWeight: 700,
              letterSpacing: '-0.03em',
              fontSize: { xs: '0.95rem', sm: '1.05rem' },
              display: { xs: 'none', md: 'block' },
            }}
          >
            WaypointMetric
          </Typography>
        </Box>

        <ToggleButtonGroup
          exclusive
          value={cabinetMode}
          onChange={onCabinetModeChange}
          size="small"
          sx={{
            display: { xs: 'none', md: 'flex' },
            mr: 1.5,
            flexShrink: 0,
            '& .MuiToggleButton-root': { px: 1.25, py: 0.35, fontSize: '0.72rem', textTransform: 'none' },
          }}
        >
          <ToggleButton value="business">Бизнес</ToggleButton>
          <ToggleButton value="developer">Разработка</ToggleButton>
        </ToggleButtonGroup>

        <Typography
          variant="subtitle1"
          noWrap
          sx={{
            flexGrow: 1,
            fontWeight: 600,
            letterSpacing: '-0.02em',
            fontSize: { xs: '0.8rem', sm: '0.95rem' },
            color: 'text.secondary',
            display: { xs: 'block', sm: 'block' },
            minWidth: 0,
          }}
        >
          {getPageTitle()}
        </Typography>

        <Box
          sx={{
            display: { xs: 'none', lg: 'flex' },
            alignItems: 'center',
            bgcolor: alpha(theme.palette.common.white, theme.palette.mode === 'dark' ? 0.06 : 0.08),
            borderRadius: 2,
            px: 1.75,
            py: 0.5,
            mr: 2,
            maxWidth: 280,
          }}
        >
          <GlobalSearch />
        </Box>

        <Box sx={{ display: { xs: 'none', md: 'flex' }, alignItems: 'center', gap: 0.25, mr: 1 }}>
          <Button
            size="small"
            color="inherit"
            component={RouterLink}
            to="/docs"
            startIcon={<MenuBook sx={{ fontSize: 20 }} />}
            sx={{ textTransform: 'none', fontWeight: 600, color: 'text.secondary', minWidth: 0, px: 1 }}
          >
            Документация
          </Button>
          <Button
            size="small"
            color="inherit"
            component={RouterLink}
            to="/platform"
            startIcon={<Layers sx={{ fontSize: 20 }} />}
            sx={{ textTransform: 'none', fontWeight: 600, color: 'text.secondary', minWidth: 0, px: 1 }}
          >
            Платформа
          </Button>
        </Box>

        <IconButton onClick={toggleTheme} sx={{ mr: 0.5 }} color="inherit" size="small">
          {mode === 'dark' ? <Brightness7 /> : <Brightness4 />}
        </IconButton>
        <PwaInstallButton sx={{ mr: 1, display: { xs: 'none', md: 'inline-flex' } }} />

        <IconButton sx={{ mr: 0.5 }} onClick={(e) => setNotificationAnchor(e.currentTarget)} size="small" color="inherit">
          <Badge badgeContent={0} color="error" invisible>
            <Notifications />
          </Badge>
        </IconButton>

        <IconButton
          sx={{ mr: 0.5 }}
          component={Link}
          href="https://t.me/AlegroMay"
          target="_blank"
          rel="noreferrer"
          size="small"
          color="inherit"
        >
          <Help />
        </IconButton>

        <IconButton onClick={openAccountPanel} size="small" sx={{ ml: 0.5, p: accountInDrawer ? 0.5 : 0.5 }} aria-label="Аккаунт">
          <Avatar
            sx={{
              width: accountInDrawer ? 36 : 32,
              height: accountInDrawer ? 36 : 32,
              bgcolor: 'primary.main',
              fontSize: accountInDrawer ? '0.95rem' : '0.9rem',
            }}
          >
            {user?.fullName?.charAt(0) || 'A'}
          </Avatar>
        </IconButton>

        <Drawer
          anchor="right"
          open={accountDrawerOpen}
          onClose={() => setAccountDrawerOpen(false)}
          PaperProps={{
            sx: {
              width: 'min(100vw, 380px)',
              maxWidth: '100%',
              bgcolor: theme.palette.mode === 'dark' ? WM_CLOUD.paperElevated : theme.palette.background.paper,
              borderLeft: `1px solid ${theme.palette.divider}`,
            },
          }}
        >
          <Box sx={{ p: 2, pb: 1.5, display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 1 }}>
            <Box sx={{ minWidth: 0 }}>
              <Typography variant="subtitle1" fontWeight={800} noWrap>
                {user?.fullName || 'Аккаунт'}
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ wordBreak: 'break-all' }}>
                {user?.email}
              </Typography>
            </Box>
            <IconButton aria-label="Закрыть" onClick={() => setAccountDrawerOpen(false)} size="small">
              <Close />
            </IconButton>
          </Box>
          <Box sx={{ px: 2, pb: 2 }}>
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 0.75, fontWeight: 600 }}>
              Режим кабинета
            </Typography>
            <ToggleButtonGroup
              exclusive
              fullWidth
              value={cabinetMode}
              onChange={(_, next) => {
                if (!next) return;
                setCabinetMode(next);
                if (next === 'business' && location.pathname.startsWith('/dashboard/lynx-cloud')) navigate('/dashboard');
                if (next === 'developer' && location.pathname.startsWith('/dashboard/business/ai')) navigate('/dashboard/lynx-cloud');
              }}
              size="medium"
              sx={{ '& .MuiToggleButton-root': { py: 1, textTransform: 'none', fontWeight: 600 } }}
            >
              <ToggleButton value="business">Основное</ToggleButton>
              <ToggleButton value="developer">Сервер</ToggleButton>
            </ToggleButtonGroup>
            <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block', lineHeight: 1.45 }}>
              Основное — метрики и Desktop. Сервер — Lynx Cloud, BaaS, ingest для арендованной инфраструктуры.
            </Typography>
          </Box>
          <Divider />
          <List sx={{ py: 1, '& .MuiListItemIcon-root': { minWidth: 44 } }}>
            <ListItemButton
              sx={{ py: 1.25 }}
              onClick={() => {
                navigate('/dashboard/settings');
                setAccountDrawerOpen(false);
              }}
            >
              <ListItemIcon>
                <Settings />
              </ListItemIcon>
              <ListItemText primary="Настройки" secondary="Профиль и безопасность" primaryTypographyProps={{ fontWeight: 600 }} />
            </ListItemButton>
            <ListItemButton
              sx={{ py: 1.25 }}
              onClick={() => {
                navigate('/dashboard/billing');
                setAccountDrawerOpen(false);
              }}
            >
              <ListItemIcon>
                <AccountBalanceWallet />
              </ListItemIcon>
              <ListItemText primary="Баланс и планы" primaryTypographyProps={{ fontWeight: 600 }} />
            </ListItemButton>
            <ListItemButton component={RouterLink} to="/docs" sx={{ py: 1.25 }} onClick={() => setAccountDrawerOpen(false)}>
              <ListItemIcon>
                <MenuBook />
              </ListItemIcon>
              <ListItemText primary="Документация" primaryTypographyProps={{ fontWeight: 600 }} />
            </ListItemButton>
            <ListItemButton component={RouterLink} to="/platform" sx={{ py: 1.25 }} onClick={() => setAccountDrawerOpen(false)}>
              <ListItemIcon>
                <Layers />
              </ListItemIcon>
              <ListItemText primary="Платформа" primaryTypographyProps={{ fontWeight: 600 }} />
            </ListItemButton>
            <ListItemButton sx={{ py: 1.25 }} onClick={() => toggleTheme()}>
              <ListItemIcon>{mode === 'dark' ? <Brightness7 /> : <Brightness4 />}</ListItemIcon>
              <ListItemText primary={mode === 'dark' ? 'Светлая тема' : 'Тёмная тема'} primaryTypographyProps={{ fontWeight: 600 }} />
            </ListItemButton>
            <ListItemButton sx={{ py: 1.25 }} onClick={handleLogout}>
              <ListItemIcon>
                <Logout color="error" />
              </ListItemIcon>
              <ListItemText primary="Выйти" primaryTypographyProps={{ fontWeight: 600, color: 'error.main' }} />
            </ListItemButton>
          </List>
        </Drawer>

        <Menu
          anchorEl={anchorEl}
          open={Boolean(anchorEl) && !accountInDrawer}
          onClose={() => setAnchorEl(null)}
          PaperProps={{
            sx: {
              borderRadius: 2,
              mt: 1,
              minWidth: 240,
              boxShadow: theme.shadows[10],
            },
          }}
        >
          <MenuItem
            onClick={() => {
              navigate('/dashboard/settings');
              closeAccountUi();
            }}
          >
            <AccountCircle sx={{ mr: 1 }} /> Профиль и настройки
          </MenuItem>
          <MenuItem
            onClick={() => {
              navigate('/dashboard/billing');
              closeAccountUi();
            }}
          >
            <AccountBalanceWallet sx={{ mr: 1 }} /> Баланс
          </MenuItem>
          <MenuItem onClick={handleLogout}>
            <Logout sx={{ mr: 1 }} /> Выйти
          </MenuItem>
        </Menu>

        <Menu
          anchorEl={notificationAnchor}
          open={Boolean(notificationAnchor)}
          onClose={() => setNotificationAnchor(null)}
          PaperProps={{
            sx: {
              borderRadius: 2,
              mt: 1,
              width: 320,
              maxHeight: 400,
            },
          }}
        >
          <MenuItem disabled>
            <Typography variant="body2" color="text.secondary">
              Пока нет новых уведомлений
            </Typography>
          </MenuItem>
        </Menu>
      </Toolbar>
    </AppBar>
  );
};
