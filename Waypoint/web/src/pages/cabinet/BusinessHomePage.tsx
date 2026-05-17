import React from 'react';
import {
  Box,
  Card,
  CardActionArea,
  CardContent,
  Grid,
  Stack,
  Typography,
  alpha,
  Chip,
  useTheme,
} from '@mui/material';
import {
  AccountBalanceWallet,
  Description,
  LocalShipping,
  QueryStats,
  ReceiptLong,
  Redeem,
  SmartToy,
  TableChart,
  Insights,
} from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { WM_CLOUD } from '../../components/layout/cloudShell';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';

const CARDS = [
  {
    to: '/dashboard/business/ai',
    title: 'AI для бизнеса',
    body: 'Отчёты, метрики, идеи автоматизации. Модель ориентирована на аналитику и операции.',
    icon: <SmartToy color="primary" />,
    tier: 'Basic: лимит сообщений · Pro: расширенно',
  },
  {
    to: '/dashboard/ingest-lab/summary',
    title: 'Дашборды и метрики',
    body: 'Сводки ingest, каналы событий, обзор нагрузки.',
    icon: <QueryStats color="primary" />,
    tier: 'Бесплатно с ограничениями',
  },
  {
    to: '/dashboard/business/documents',
    title: 'Документы',
    body: 'Шаблоны под службы доставки, акты, счета — связка с BaaS и экспорт.',
    icon: <Description color="primary" />,
    tier: 'Расширенный пакет — Pro',
  },
  {
    to: '/dashboard/business/vouchers',
    title: 'Ваучеры и промо',
    body: 'Промокоды, кампании, учёт погашений.',
    icon: <Redeem color="primary" />,
    tier: 'Массовые операции — Pro',
  },
  {
    to: '/dashboard/business/ledger',
    title: 'Учёт (лёгкий ERP)',
    body: 'Остатки, контрагенты, проводки поверх PostgreSQL / BaaS.',
    icon: <TableChart color="primary" />,
    tier: 'Мультисклад — Pro',
  },
  {
    to: '/dashboard/business/logistics',
    title: 'Логистика',
    body: 'Отправления, статусы, интеграция с событиями и вебхуками.',
    icon: <LocalShipping color="primary" />,
    tier: 'Вебхуки / API — Pro',
  },
  {
    to: '/dashboard/business/tax',
    title: 'Налоги и отчётность',
    body: 'Чеклисты и черновики выгрузок (без юридических гарантий).',
    icon: <ReceiptLong color="primary" />,
    tier: 'Экспорт отчётов — Pro',
  },
  {
    to: '/dashboard/billing',
    title: 'Баланс и планы',
    body: 'Basic / Pro, платежи, лимиты.',
    icon: <AccountBalanceWallet color="primary" />,
    tier: '',
  },
];

export const BusinessHomePage: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const { workspace } = useWorkspace();
  const isDark = theme.palette.mode === 'dark';

  return (
    <Stack spacing={3}>
      <Box
        sx={{
          borderRadius: 3,
          p: { xs: 2.25, sm: 3 },
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
          background: isDark
            ? `linear-gradient(125deg, ${alpha(WM_CLOUD.paperElevated, 0.9)} 0%, ${alpha(WM_CLOUD.accent, 0.07)} 100%)`
            : `linear-gradient(125deg, ${theme.palette.background.paper} 0%, ${alpha(theme.palette.primary.main, 0.06)} 100%)`,
        }}
      >
        <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
          <Insights color="primary" />
          <Typography variant="overline" sx={{ fontWeight: 700, letterSpacing: '0.12em' }}>
            Кабинет · бизнес
          </Typography>
        </Stack>
        <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.02em', fontSize: { xs: '1.5rem', sm: '2rem' } }}>
          Метрики, ИИ, документы и учёт без привязки к игровому движку
        </Typography>
        <Typography variant="body1" color="text.secondary" sx={{ mt: 1.25, maxWidth: 800, lineHeight: 1.7 }}>
          WaypointMetric для операций: дашборды ingest, AI для отчётов, ваучеры, логистика и налоговые черновики поверх одной
          платформы данных. Инфраструктура кода и Lynx Cloud — в режиме «Разработка».
        </Typography>
        <Chip
          size="small"
          sx={{ mt: 1.75 }}
          label={workspace.plan === 'pro' ? 'План Pro — расширенные модули' : 'План Basic — часть функций с замком'}
          color={workspace.plan === 'pro' ? 'primary' : 'default'}
          variant={workspace.plan === 'pro' ? 'filled' : 'outlined'}
        />
      </Box>

      <Grid container spacing={2}>
        {CARDS.map((c) => (
          <Grid item xs={12} sm={6} md={4} key={c.to}>
            <Card
              sx={{
                borderRadius: 3,
                height: '100%',
                border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
                bgcolor: isDark ? alpha(WM_CLOUD.paperElevated, 0.4) : theme.palette.background.paper,
              }}
            >
              <CardActionArea onClick={() => navigate(c.to)} sx={{ height: '100%', alignItems: 'stretch' }}>
                <CardContent sx={{ p: 2.25, height: '100%', display: 'flex', flexDirection: 'column' }}>
                  <Stack direction="row" spacing={1.25} alignItems="flex-start">
                    <Box sx={{ mt: 0.25 }}>{c.icon}</Box>
                    <Box sx={{ minWidth: 0 }}>
                      <Typography variant="subtitle1" fontWeight={700}>
                        {c.title}
                      </Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ mt: 0.75, lineHeight: 1.55 }}>
                        {c.body}
                      </Typography>
                      {c.tier && (
                        <Typography variant="caption" color="text.secondary" sx={{ mt: 1.2, display: 'block' }}>
                          {c.tier}
                        </Typography>
                      )}
                    </Box>
                  </Stack>
                </CardContent>
              </CardActionArea>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Stack>
  );
};
