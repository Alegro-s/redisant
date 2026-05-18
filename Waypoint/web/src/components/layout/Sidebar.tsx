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
import {
  Dashboard,
  Source,
  QueryStats,
  Science,
  Storage,
  AutoGraph,
  Api,
  DataObject,
  Group,
  Cloud,
  Folder,
  Settings,
  LockOutlined,
  Launch,
  Cable,
  SmartToy,
  CloudQueue,
  Hub,
  AccountBalanceWallet,
  MenuBook,
  Description,
  Redeem,
  TableChart,
  LocalShipping,
  ReceiptLong,
  Code,
  HomeWork,
  Computer,
} from '@mui/icons-material';
import { useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from '../../app/contexts/AuthContext';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { useCabinetMode, type CabinetMode } from '../../app/contexts/CabinetModeContext';
import { PremiumIconBadge } from '../common/PremiumIconBadge';
import { DRAWER_WIDTH, RAIL_WIDTH } from './layoutConstants';
import { WM_CLOUD } from './cloudShell';

interface SidebarProps {
  onClose?: () => void;
}

type MenuItem = {
  text: string;
  icon: React.ReactNode;
  path: string;
  requiresServer?: boolean;
  secondary?: string;
};

const businessNavSections: { title: string; items: MenuItem[] }[] = [
  {
    title: 'Панель',
    items: [
      { text: 'Рабочий стол', icon: <HomeWork />, path: '/dashboard', secondary: 'Все зоны' },
      { text: 'Главная бизнеса', icon: <Dashboard />, path: '/dashboard/business' },
      { text: 'Обзор платформы', icon: <Dashboard />, path: '/dashboard/overview', secondary: 'Общая сводка' },
    ],
  },
  {
    title: 'Метрики и витрина',
    items: [
      {
        text: 'WaypointMetric',
        secondary: 'Hub · каталог',
        icon: <QueryStats />,
        path: '/dashboard/waypoint',
      },
      { text: 'Сводки ingest', icon: <AutoGraph />, path: '/dashboard/ingest-lab/summary' },
    ],
  },
  {
    title: 'Операции',
    items: [
      { text: 'AI для бизнеса', icon: <SmartToy />, path: '/dashboard/business/ai' },
      { text: 'Документы', icon: <Description />, path: '/dashboard/business/documents' },
      { text: 'Ваучеры', icon: <Redeem />, path: '/dashboard/business/vouchers' },
      { text: 'Учёт (ERP-lite)', icon: <TableChart />, path: '/dashboard/business/ledger' },
      { text: 'Логистика', icon: <LocalShipping />, path: '/dashboard/business/logistics' },
      { text: 'Налоги', icon: <ReceiptLong />, path: '/dashboard/business/tax' },
    ],
  },
  {
    title: 'Аккаунт',
    items: [
      { text: 'Подключение', secondary: 'SDK, ключи', icon: <Cable />, path: '/dashboard/connect' },
      { text: 'Баланс и платежи', icon: <AccountBalanceWallet />, path: '/dashboard/billing' },
    ],
  },
];

const developerNavSections: { title: string; items: MenuItem[] }[] = [
  {
    title: 'Панель',
    items: [
      { text: 'Рабочий стол', icon: <HomeWork />, path: '/dashboard', secondary: 'Все зоны' },
      { text: 'Главная разработки', icon: <Code />, path: '/dashboard/developer' },
      { text: 'Обзор платформы', icon: <Dashboard />, path: '/dashboard/overview' },
    ],
  },
  {
    title: 'Инфраструктура',
    items: [
      { text: 'Lynx Cloud', secondary: 'Проекты · ядро · сборки', icon: <Hub />, path: '/dashboard/lynx-cloud', requiresServer: true },
      { text: 'Проекты', icon: <Folder />, path: '/dashboard/projects' },
      { text: 'PostgreSQL', icon: <Storage />, path: '/dashboard/database', requiresServer: true },
      { text: 'BaaS', icon: <CloudQueue />, path: '/dashboard/baas', requiresServer: true },
      { text: 'API', icon: <Api />, path: '/dashboard/api', requiresServer: true },
      { text: 'Git', icon: <Source />, path: '/dashboard/git' },
      { text: 'Графика', icon: <AutoGraph />, path: '/dashboard/graphics' },
      { text: 'Тестирование', icon: <Science />, path: '/dashboard/module-testing', requiresServer: true },
      { text: 'AI Copilot', icon: <SmartToy />, path: '/dashboard/developer/ai' },
    ],
  },
  {
    title: 'Метрики и ingest',
    items: [
      { text: 'Ingest Lab', icon: <QueryStats />, path: '/dashboard/ingest-lab' },
      { text: 'Desktop hosts', icon: <Computer />, path: '/dashboard/desktop-hosts' },
      { text: 'WaypointMetric', icon: <Hub />, path: '/dashboard/waypoint', secondary: 'Витрина' },
    ],
  },
  {
    title: 'Интеграции',
    items: [
      { text: 'Подключение', secondary: 'SDK, ключи', icon: <Cable />, path: '/dashboard/connect' },
      { text: 'VK-бот', icon: <SmartToy />, path: '/dashboard/vk-bot' },
    ],
  },
  {
    title: 'Аккаунт',
    items: [{ text: 'Баланс и платежи', icon: <AccountBalanceWallet />, path: '/dashboard/billing' }],
  },
];

const adminExtensions: { text: string; secondary?: string; icon: React.ReactNode; path: string }[] = [
  { text: 'Users', icon: <Group />, path: '/dashboard/users' },
  { text: 'Server Rent', icon: <Cloud />, path: '/dashboard/instances' },
  { text: 'Realtime', icon: <DataObject />, path: '/dashboard/realtime' },
  { text: 'Projects', icon: <Folder />, path: '/dashboard/projects' },
];

const railItemsBusiness: { icon: React.ReactNode; path: string; label: string; match?: (p: string) => boolean }[] = [
  {
    icon: <HomeWork />,
    path: '/dashboard',
    label: 'Стол',
    match: (p) => p === '/dashboard',
  },
  {
    icon: <Dashboard />,
    path: '/dashboard/business',
    label: 'Бизнес',
    match: (p) => p.startsWith('/dashboard/business'),
  },
  {
    icon: <QueryStats />,
    path: '/dashboard/waypoint',
    label: 'Waypoint',
    match: (p) => p.startsWith('/dashboard/waypoint') || p.startsWith('/dashboard/ingest-lab'),
  },
  { icon: <SmartToy />, path: '/dashboard/business/ai', label: 'AI', match: (p) => p === '/dashboard/business/ai' },
  {
    icon: <AccountBalanceWallet />,
    path: '/dashboard/billing',
    label: 'Баланс',
    match: (p) => p.startsWith('/dashboard/billing'),
  },
  { icon: <Settings />, path: '/dashboard/settings', label: 'Настройки', match: (p) => p.startsWith('/dashboard/settings') },
];

const railItemsDeveloper: { icon: React.ReactNode; path: string; label: string; match?: (p: string) => boolean }[] = [
  {
    icon: <HomeWork />,
    path: '/dashboard',
    label: 'Стол',
    match: (p) => p === '/dashboard',
  },
  {
    icon: <Code />,
    path: '/dashboard/developer',
    label: 'Dev',
    match: (p) => p.startsWith('/dashboard/developer'),
  },
  {
    icon: <QueryStats />,
    path: '/dashboard/ingest-lab',
    label: 'Ingest',
    match: (p) => p.startsWith('/dashboard/ingest-lab'),
  },
  { icon: <CloudQueue />, path: '/dashboard/baas', label: 'BaaS', match: (p) => p.startsWith('/dashboard/baas') },
  { icon: <Hub />, path: '/dashboard/lynx-cloud', label: 'Cloud', match: (p) => p.startsWith('/dashboard/lynx-cloud') },
  { icon: <Source />, path: '/dashboard/git', label: 'Git', match: (p) => p.startsWith('/dashboard/git') },
  { icon: <Settings />, path: '/dashboard/settings', label: 'Настройки', match: (p) => p.startsWith('/dashboard/settings') },
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
  const visibleSections = workspace.setupCompleted
    ? mode === 'business'
      ? businessNavSections
      : developerNavSections
    : [];
  const railItems = mode === 'business' ? railItemsBusiness : railItemsDeveloper;
  const hasServerConnection = workspace.serverConnected || workspace.setupMode === 'rent' || workspace.plan === 'pro';

  const onCabinetModeChange = (_: React.MouseEvent<HTMLElement>, next: CabinetMode | null) => {
    if (!next) return;
    setMode(next);
    if (next === 'business' && location.pathname.startsWith('/dashboard/developer')) {
      navigate('/dashboard/business');
      onClose?.();
    } else if (next === 'developer' && location.pathname.startsWith('/dashboard/business')) {
      navigate('/dashboard/developer');
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
      {}
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
            sx={{
              border: 'none',
              background: 'none',
              cursor: 'pointer',
              p: 0,
              mb: 1,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Box component="img" src="/favicon.svg" alt="" sx={{ width: 26, height: 26, display: 'block' }} />
          </Box>
        </Tooltip>
        {railItems.map((r) => {
          const active = r.match ? r.match(location.pathname) : location.pathname === r.path;
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
                  '&:hover': {
                    bgcolor: active ? alpha(theme.palette.primary.main, 0.2) : alpha(theme.palette.action.hover, 0.12),
                  },
                }}
              >
                {r.icon}
              </IconButton>
            </Tooltip>
          );
        })}
        <Box sx={{ flexGrow: 1 }} />
        <Tooltip title="Workspace setup" placement="right">
          <IconButton
            size="medium"
            onClick={() => handleNavigation('/workspace/setup')}
            sx={{
              borderRadius: 2,
              minWidth: 44,
              minHeight: 44,
              color: location.pathname.startsWith('/workspace/setup') ? 'primary.main' : 'text.secondary',
              bgcolor: location.pathname.startsWith('/workspace/setup')
                ? alpha(theme.palette.primary.main, 0.14)
                : 'transparent',
            }}
          >
            <Cloud fontSize="small" />
          </IconButton>
        </Tooltip>
      </Box>

      <Box
        sx={{
          width: navWidth,
          minWidth: 0,
          display: 'flex',
          flexDirection: 'column',
          bgcolor: panelBg,
        }}
      >
        <Box sx={{ px: 2, pt: 2, pb: 1 }}>
          <Typography sx={{ fontWeight: 750, letterSpacing: '-0.03em', fontSize: '0.95rem' }}>Консоль</Typography>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.25, lineHeight: 1.4 }}>
            {mode === 'business'
              ? 'Бизнес: метрики, документы, логистика, AI'
              : 'Разработка: облако, БД, BaaS, Copilot'}
          </Typography>
          <ToggleButtonGroup
            exclusive
            value={mode}
            onChange={onCabinetModeChange}
            size="small"
            sx={{ mt: 1.25, width: '100%', '& .MuiToggleButton-root': { flex: 1, py: 0.5, fontSize: '0.72rem' } }}
          >
            <ToggleButton value="business">Бизнес</ToggleButton>
            <ToggleButton value="developer">Разработка</ToggleButton>
          </ToggleButtonGroup>
        </Box>

        <Divider sx={{ mx: 2, borderColor: theme.palette.mode === 'dark' ? WM_CLOUD.border : undefined }} />

        <List sx={{ flexGrow: 1, px: 1.25, py: 1.25, overflowY: 'auto' }}>
          {!workspace.setupCompleted && (
            <ListItem disablePadding sx={{ mb: 0.75 }}>
              <ListItemButton
                onClick={() => handleNavigation('/workspace/setup')}
                selected={location.pathname === '/workspace/setup'}
                sx={{
                  borderRadius: 2,
                  py: 1.15,
                  px: 1.5,
                  border: `1px solid ${alpha(theme.palette.primary.main, 0.22)}`,
                  backgroundColor: alpha(theme.palette.primary.main, 0.07),
                }}
              >
                <ListItemIcon sx={{ minWidth: 40 }}>
                  <PremiumIconBadge icon={<Cloud fontSize="small" />} active={location.pathname === '/workspace/setup'} />
                </ListItemIcon>
                <ListItemText primary="Setup workspace" primaryTypographyProps={{ fontSize: '0.88rem', fontWeight: 600 }} />
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
                        <Tooltip title="Подключить сервер в Setup">
                          <IconButton
                            edge="end"
                            size="small"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleNavigation('/workspace/setup');
                            }}
                          >
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
                        pr: isLocked ? 4.5 : 1.5,
                        border: `1px solid ${isSelected && !isLocked ? alpha(theme.palette.primary.main, 0.28) : 'transparent'}`,
                        backgroundColor: isSelected && !isLocked ? alpha(theme.palette.primary.main, 0.1) : 'transparent',
                        opacity: isLocked ? 0.78 : 1,
                        '&:hover': {
                          backgroundColor: alpha(theme.palette.primary.main, 0.06),
                        },
                        '&.Mui-selected': {
                          backgroundColor: alpha(theme.palette.primary.main, 0.1),
                          '&:hover': { backgroundColor: alpha(theme.palette.primary.main, 0.14) },
                        },
                      }}
                    >
                      <ListItemIcon sx={{ minWidth: 38 }}>
                        <Tooltip title={isLocked ? 'Нужен подключённый сервер или аренда' : ''} placement="right" disableInteractive={!isLocked}>
                          <Box>
                            <PremiumIconBadge
                              icon={isLocked ? <LockOutlined sx={{ fontSize: 18 }} /> : item.icon}
                              active={isSelected && !isLocked}
                              size={28}
                            />
                          </Box>
                        </Tooltip>
                      </ListItemIcon>
                      <ListItemText
                        primary={item.text}
                        primaryTypographyProps={{
                          fontWeight: isSelected && !isLocked ? 600 : 450,
                          fontSize: '0.86rem',
                        }}
                        secondary={isLocked ? 'Требуется сервер' : item.secondary}
                        secondaryTypographyProps={{ sx: { mt: 0.15, fontSize: '0.68rem' } }}
                      />
                    </ListItemButton>
                  </ListItem>
                );
              })}
            </React.Fragment>
          ))}
          {workspace.setupCompleted && !hasServerConnection && (
            <Box sx={{ px: 1.75, pt: 1 }}>
              <Typography variant="caption" color="text.secondary" sx={{ lineHeight: 1.45 }}>
                Часть разделов скрыта до подключения сервера. Откройте «Setup workspace».
              </Typography>
            </Box>
          )}
          {can('users:manage') && workspace.setupCompleted && (
            <>
              <Divider sx={{ my: 1.25, mx: 0.5 }} />
              <Typography component="span" sx={sectionLabelSx(theme)}>Администрирование</Typography>
              {adminExtensions.map((item) => {
                const isSelected = location.pathname === item.path || location.pathname.startsWith(`${item.path}/`);
                return (
                  <ListItem key={item.text} disablePadding sx={{ mb: 0.35 }}>
                    <ListItemButton
                      onClick={() => handleNavigation(item.path)}
                      selected={isSelected}
                      sx={{
                        borderRadius: 2,
                        py: 1,
                        px: 1.5,
                        border: `1px solid ${isSelected ? alpha(theme.palette.primary.main, 0.28) : 'transparent'}`,
                        '&.Mui-selected': { backgroundColor: alpha(theme.palette.primary.main, 0.1) },
                      }}
                    >
                      <ListItemIcon sx={{ minWidth: 38 }}>
                        <PremiumIconBadge icon={item.icon} active={isSelected} size={28} />
                      </ListItemIcon>
                      <ListItemText
                        primary={item.text}
                        secondary={item.secondary}
                        primaryTypographyProps={{ fontSize: '0.86rem' }}
                        secondaryTypographyProps={{ sx: { mt: 0.15, fontSize: '0.68rem' } }}
                      />
                    </ListItemButton>
                  </ListItem>
                );
              })}
            </>
          )}
        </List>

        <Divider sx={{ mx: 2, borderColor: theme.palette.mode === 'dark' ? WM_CLOUD.border : undefined }} />

        <Box sx={{ p: 1.5, display: 'flex', flexDirection: 'column', alignItems: 'stretch', gap: 1 }}>
          <ListItemButton
            component="a"
            href="/docs"
            sx={{ borderRadius: 2, py: 0.85, px: 1.5, border: `1px solid ${alpha(theme.palette.primary.main, 0.2)}` }}
          >
            <ListItemIcon sx={{ minWidth: 36 }}>
              <MenuBook fontSize="small" color="primary" />
            </ListItemIcon>
            <ListItemText primary="Документация" primaryTypographyProps={{ fontSize: '0.82rem', fontWeight: 600 }} />
          </ListItemButton>
          <Box sx={{ display: 'flex', justifyContent: 'center' }}>
            <Chip
              size="small"
              color={workspace.plan === 'pro' ? 'primary' : 'default'}
              variant={workspace.plan === 'pro' ? 'filled' : 'outlined'}
              label={workspace.plan === 'pro' ? 'План: Pro' : 'План: Basic'}
              sx={{ fontWeight: 600, borderRadius: 2 }}
            />
          </Box>
        </Box>
      </Box>
    </Box>
  );
};
