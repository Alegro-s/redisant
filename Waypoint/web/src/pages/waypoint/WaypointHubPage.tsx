import React from 'react';
import {
  Box,
  Button,
  Card,
  CardContent,
  Grid,
  Stack,
  Typography,
  Chip,
  alpha,
  useTheme,
} from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';
import {
  TrendingUp,
  Code,
  SmartToy,
  AutoAwesome,
  Hub,
  QueryStats,
  Login,
  Storage,
  Analytics,
} from '@mui/icons-material';
import { WAYPOINT_PROMOTIONS } from '../../waypoint/waypointCatalog';
import { WM_CLOUD } from '../../components/layout/cloudShell';

export const WaypointHubPage: React.FC = () => {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';

  const pillar = (opts: {
    to: string;
    title: string;
    subtitle: string;
    icon: React.ReactNode;
    cta: string;
  }) => (
    <Card
      component={RouterLink}
      to={opts.to}
      sx={{
        height: '100%',
        textDecoration: 'none',
        color: 'inherit',
        borderRadius: 3,
        border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
        bgcolor: isDark ? alpha(WM_CLOUD.paperElevated, 0.6) : theme.palette.background.paper,
        transition: 'transform 0.22s ease, box-shadow 0.22s ease',
        '&:hover': {
          transform: 'translateY(-4px)',
          boxShadow: isDark ? '0 20px 50px rgba(0,0,0,0.35)' : '0 16px 48px rgba(0,0,0,0.08)',
        },
      }}
    >
      <CardContent sx={{ p: 3 }}>
        <Stack direction="row" alignItems="flex-start" justifyContent="space-between" spacing={2}>
          <Box>
            <Typography variant="overline" color="primary" sx={{ fontWeight: 700 }}>
              {opts.subtitle}
            </Typography>
            <Typography variant="h5" sx={{ fontWeight: 800, mt: 0.5, mb: 0.5 }}>
              {opts.title}
            </Typography>
            <Typography variant="body2" color="primary" sx={{ fontWeight: 600, mt: 1 }}>
              {opts.cta} →
            </Typography>
          </Box>
          <Box
            sx={{
              color: WM_CLOUD.accent,
              opacity: 0.9,
              '& svg': { fontSize: 48 },
            }}
          >
            {opts.icon}
          </Box>
        </Stack>
      </CardContent>
    </Card>
  );

  const step = (n: string, title: string, body: string) => (
    <Card
      key={title}
      sx={{
        borderRadius: 2.5,
        border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
        bgcolor: isDark ? alpha(WM_CLOUD.paperElevated, 0.35) : alpha(theme.palette.primary.main, 0.02),
      }}
    >
      <CardContent sx={{ p: 2.25 }}>
        <Chip label={n} size="small" sx={{ mb: 1 }} color="primary" variant="outlined" />
        <Typography variant="subtitle2" sx={{ fontWeight: 800, mb: 0.75 }}>
          {title}
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.6 }}>
          {body}
        </Typography>
      </CardContent>
    </Card>
  );

  return (
    <Box>
      <Card
        sx={{
          mb: 3,
          borderRadius: 3,
          overflow: 'hidden',
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
          background: isDark
            ? `linear-gradient(135deg, ${alpha(WM_CLOUD.paperElevated, 0.95)} 0%, ${alpha('#1a2740', 0.92)} 50%, ${alpha(WM_CLOUD.accent, 0.08)} 100%)`
            : `linear-gradient(135deg, ${theme.palette.background.paper} 0%, ${alpha(theme.palette.primary.main, 0.06)} 100%)`,
        }}
      >
        <CardContent sx={{ p: { xs: 2.5, sm: 3.5 } }}>
          <Chip label="Операционная платформа" size="small" color="primary" variant="outlined" sx={{ mb: 1.5 }} />
          <Typography
            variant="h4"
            sx={{
              fontWeight: 800,
              letterSpacing: '-0.03em',
              fontSize: { xs: '1.45rem', sm: '1.85rem' },
              lineHeight: 1.2,
              mb: 1.5,
            }}
          >
            WaypointMetric — метрики, ИИ, СУБД и аналитика отдельно от игрового движка
          </Typography>
          <Typography variant="body1" color="text.secondary" sx={{ maxWidth: 920, lineHeight: 1.7, mb: 2 }}>
            Здесь живут данные бизнеса и инфраструктура разработки: события и дашборды, AI для отчётов и кода, PostgreSQL и
            BaaS, коммерческие сценарии. Рантайм игры и редактор остаются в своём контуре — вы масштабируете продукт и
            операции, не смешивая их с билдом клиента.
          </Typography>
          <Grid container spacing={1.5}>
            {[
              { icon: <QueryStats />, t: 'Метрика', d: 'Ingest, сводки, наблюдаемость' },
              { icon: <SmartToy />, t: 'ИИ', d: 'Бизнес-аналитика и Copilot' },
              { icon: <Storage />, t: 'СУБД и API', d: 'SQL, BaaS, ключи агента' },
              { icon: <Analytics />, t: 'Аналитика', d: 'ERP-lite, логистика, отчёты' },
            ].map((x) => (
              <Grid item xs={6} md={3} key={x.t}>
                <Box
                  sx={{
                    p: 1.5,
                    borderRadius: 2,
                    height: '100%',
                    border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
                    bgcolor: isDark ? alpha(WM_CLOUD.paperElevated, 0.4) : alpha(theme.palette.primary.main, 0.04),
                  }}
                >
                  <Box sx={{ color: 'primary.main', mb: 0.75, '& svg': { fontSize: 26 } }}>{x.icon}</Box>
                  <Typography variant="subtitle2" fontWeight={800}>
                    {x.t}
                  </Typography>
                  <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.5, lineHeight: 1.45 }}>
                    {x.d}
                  </Typography>
                </Box>
              </Grid>
            ))}
          </Grid>
        </CardContent>
      </Card>

      <Typography variant="body1" color="text.secondary" sx={{ mb: 3, maxWidth: 900, lineHeight: 1.65 }}>
        <strong>Навигация:</strong> один логин — кабинет. На телефоне и планшете меню аккаунта открывается из аватара
        (режим «Бизнес / Разработка», баланс, документация). Сайдбар и нижняя полоса дают быстрый доступ к метрикам и AI.
        Рабочие экраны — в{' '}
        <RouterLink to="/dashboard/business">бизнес-панели</RouterLink>,{' '}
        <RouterLink to="/dashboard/developer">панели разработчика</RouterLink> и{' '}
        <RouterLink to="/dashboard/lynx-cloud">Lynx Cloud</RouterLink> при подключённом сервере.
      </Typography>

      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
        <Login sx={{ color: WM_CLOUD.accent, fontSize: 22 }} />
        <Typography variant="h6" sx={{ fontWeight: 700 }}>
          С чего начать
        </Typography>
      </Stack>
      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          {step('1', 'Workspace', 'Завершите Setup: аренда или свой сервер, ключи ingest и агента.')}
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          {step('2', 'Режим кабинета', 'Бизнес — метрики, документы, ваучеры, AI для аналитики. Разработка — БД, BaaS, Lynx Cloud, Copilot.')}
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          {step('3', 'События', 'Направляйте ingest в WaypointMetric; смотрите сводки в Ingest Lab.')}
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          {step('4', 'Облако Lynx', 'Проекты, сборки и ядро — в Lynx Cloud, если сервер подключён.')}
        </Grid>
      </Grid>

      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
        <AutoAwesome sx={{ color: WM_CLOUD.accent }} />
        <Typography variant="h6" sx={{ fontWeight: 700 }}>
          Быстрый вход в сценарии
        </Typography>
      </Stack>
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} md={6}>
          {pillar({
            to: '/dashboard/business',
            subtitle: 'Операции · отчёты · AI бизнес',
            title: 'Кабинет «Бизнес»',
            icon: <TrendingUp />,
            cta: 'Открыть главную бизнеса',
          })}
        </Grid>
        <Grid item xs={12} md={6}>
          {pillar({
            to: '/dashboard/developer',
            subtitle: 'Облако · БД · Copilot',
            title: 'Кабинет «Разработка»',
            icon: <Code />,
            cta: 'Открыть главную разработки',
          })}
        </Grid>
      </Grid>

      <Grid container spacing={2} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card
            component={RouterLink}
            to="/dashboard/waypoint/business"
            sx={{
              height: '100%',
              textDecoration: 'none',
              color: 'inherit',
              borderRadius: 2,
              border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
            }}
          >
            <CardContent sx={{ py: 2 }}>
              <Typography variant="caption" color="text.secondary">
                Каталог услуг
              </Typography>
              <Typography variant="subtitle2" sx={{ fontWeight: 700, mt: 0.5 }}>
                Для бизнеса (витрина)
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card
            component={RouterLink}
            to="/dashboard/waypoint/developers"
            sx={{
              height: '100%',
              textDecoration: 'none',
              color: 'inherit',
              borderRadius: 2,
              border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
            }}
          >
            <CardContent sx={{ py: 2 }}>
              <Typography variant="caption" color="text.secondary">
                Каталог услуг
              </Typography>
              <Typography variant="subtitle2" sx={{ fontWeight: 700, mt: 0.5 }}>
                Для разработчиков (витрина)
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card
            component={RouterLink}
            to="/dashboard/lynx-cloud"
            sx={{
              height: '100%',
              textDecoration: 'none',
              color: 'inherit',
              borderRadius: 2,
              border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
            }}
          >
            <CardContent sx={{ py: 2 }}>
              <Stack direction="row" alignItems="center" spacing={1}>
                <Hub fontSize="small" color="primary" />
                <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>
                  Lynx Cloud
                </Typography>
              </Stack>
              <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 0.5 }}>
                Проекты, ядро, сборки
              </Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card
            component={RouterLink}
            to="/dashboard/ingest-lab/summary"
            sx={{
              height: '100%',
              textDecoration: 'none',
              color: 'inherit',
              borderRadius: 2,
              border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
            }}
          >
            <CardContent sx={{ py: 2 }}>
              <Stack direction="row" alignItems="center" spacing={1}>
                <QueryStats fontSize="small" color="primary" />
                <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>
                  Сводки ingest
                </Typography>
              </Stack>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
        <SmartToy sx={{ color: WM_CLOUD.accent }} />
        <Typography variant="h6" sx={{ fontWeight: 700 }}>
          AI
        </Typography>
      </Stack>
      <Card
        sx={{
          mb: 4,
          borderRadius: 3,
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
          bgcolor: isDark ? alpha(WM_CLOUD.paperElevated, 0.5) : alpha(theme.palette.primary.main, 0.04),
        }}
      >
        <CardContent sx={{ p: 3, display: 'flex', flexWrap: 'wrap', gap: 2, alignItems: 'center' }}>
          <Box sx={{ flex: '1 1 280px' }}>
            <Typography variant="subtitle1" sx={{ fontWeight: 700 }}>
              AI для бизнеса и Copilot для кода
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
              Бизнес-аналитика и черновики — в «AI для бизнеса»; код и архитектура — в «AI Copilot» (режим разработки). Квоты
              считает сервер.
            </Typography>
          </Box>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
            <Button variant="contained" component={RouterLink} to="/dashboard/business/ai" size="large">
              AI · бизнес
            </Button>
            <Button variant="outlined" component={RouterLink} to="/dashboard/developer/ai" size="large">
              AI · Copilot
            </Button>
          </Stack>
        </CardContent>
      </Card>

      <Typography variant="h6" sx={{ fontWeight: 700, mb: 2 }}>
        Предложения и пакеты
      </Typography>
      <Grid container spacing={2}>
        {WAYPOINT_PROMOTIONS.map((p) => (
          <Grid item xs={12} sm={6} md={4} key={p.title}>
            <Card
              sx={{
                height: '100%',
                borderRadius: 2,
                border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
                transition: 'transform 0.2s ease',
                '&:hover': { transform: 'translateY(-2px)' },
              }}
            >
              <CardContent>
                <Chip label={p.tag} size="small" sx={{ mb: 1 }} color="primary" variant="outlined" />
                <Typography variant="subtitle2" sx={{ fontWeight: 700 }}>
                  {p.title}
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
                  {p.detail}
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
};
