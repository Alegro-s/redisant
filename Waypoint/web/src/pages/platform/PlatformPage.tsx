import React from 'react';
import { alpha } from '@mui/material/styles';
import {
  Box,
  Button,
  Container,
  Grid,
  Typography,
  Paper,
  Chip,
  Stack,
  Link,
  Divider,
} from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';
import {
  Login,
  Email,
  MenuBook,
  Hub,
  Speed,
  Security,
  Groups,
  Terminal,
  RocketLaunch,
  CheckCircle,
  ArrowBack,
  Gavel,
  MonitorHeart,
  Language,
  AccountBalance,
} from '@mui/icons-material';

const TELEGRAM = 'https://t.me/AlegroMay';
const COL_MAX = 1040;

const pillars = [
  {
    title: 'Observe',
    subtitle: 'Телеметрия без шума',
    body: 'Метрики и логи через API-ключ, сводки в консоли, симуляция батчей до продакшена. Один контракт — любой язык (Python SDK, curl, ваш агент).',
    icon: <Speed sx={{ fontSize: 36 }} />,
  },
  {
    title: 'Ship',
    subtitle: 'Артефакты и версии',
    body: 'Полный цикл поставки 2D-ядра Lynx: политика релизов в Lynx Cloud и кабинет «Ядро Lynx»; каналы с sha256, recommended version и контролем доступа.',
    icon: <Hub sx={{ fontSize: 36 }} />,
  },
  {
    title: 'Build',
    subtitle: 'Среда для интеграции',
    body: 'Ingest Lab, ключи, модули тестирования, БД и API-хаб в одном workspace. Цель — меньше «у меня работает», больше воспроизводимых прогонов.',
    icon: <Terminal sx={{ fontSize: 36 }} />,
  },
];

const curlExample = `curl -sS -X POST "$API/api/waypoint/ingest" \\
  -H "Content-Type: application/json" \\
  -H "X-API-Key: YOUR_KEY" \\
  -d '{"metrics":[{"name":"app.ready","value":1}],"logs":[]}'`;

const rfProductPillars = [
  {
    title: 'Доверие и соответствие',
    icon: <Gavel sx={{ fontSize: 28 }} />,
    body:
      'Прозрачная модель размещения данных (в т.ч. в контуре РФ), ДПО и согласия, журналы доступа, on-prem или выделенный контур без «всё в одном зарубежном облаке» — типичное требование B2B к observability.',
  },
  {
    title: 'Кто нагружает сервер',
    icon: <MonitorHeart sx={{ fontSize: 28 }} />,
    body:
      'Готовые дашборды: топ процессов и контейнеров, разбивка по сервисам, алерты по диску, памяти и load, связка с systemd и Docker — поверх ingest и хостовых скриптов.',
  },
  {
    title: 'Локализация и поддержка',
    icon: <Language sx={{ fontSize: 28 }} />,
    body:
      'Русский UI и доки первого уровня, SLA и поддержка в часовом поясе РФ, гайды для админов, не только для разработчиков.',
  },
  {
    title: 'Платежи и договоры',
    icon: <AccountBalance sx={{ fontSize: 28 }} />,
    body:
      'Рублёвый счёт, ЭДО, типовой договор — часто важнее следующей мелкой фичи API.',
  },
  {
    title: 'Интеграции под местный стек',
    icon: <Hub sx={{ fontSize: 28 }} />,
    body:
      'Уведомления в VK/Telegram, почта у российских провайдеров, логи в S3-совместимое хранилище в РФ — по мере развития.',
  },
];

export default function PlatformPage() {
  return (
    <Box
      sx={{
        minHeight: '100vh',
        overflowX: 'hidden',
        background: (t) =>
          `linear-gradient(165deg, ${alpha(t.palette.primary.dark, 0.12)} 0%, ${t.palette.background.default} 42%, ${t.palette.background.paper} 100%)`,
      }}
    >
      <Box
        sx={(t) => ({
          position: 'sticky',
          top: 0,
          zIndex: 1100,
          borderBottom: `1px solid ${t.palette.divider}`,
          backdropFilter: 'blur(12px)',
          bgcolor: alpha(t.palette.background.paper, 0.92),
        })}
      >
        <Container maxWidth="lg">
          <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ py: 1.25 }}>
            <Button
              component={RouterLink}
              to="/"
              startIcon={<ArrowBack />}
              color="inherit"
              sx={{ fontWeight: 600 }}
            >
              Консоль WaypointMetric
            </Button>
            <Stack direction="row" spacing={1} alignItems="center">
              <Button component={RouterLink} to="/docs" startIcon={<MenuBook />} variant="outlined" size="small">
                Документация
              </Button>
              <Button component={RouterLink} to="/login" startIcon={<Login />} variant="outlined" size="small">
                Вход
              </Button>
              <Button component={RouterLink} to="/register?plan=pro" variant="contained" size="small" startIcon={<Email />}>
                Начать
              </Button>
            </Stack>
          </Stack>
        </Container>
      </Box>

      <Container maxWidth="lg" sx={{ py: { xs: 3, md: 5 } }}>
        <Stack spacing={1} sx={{ maxWidth: COL_MAX, mb: 4 }}>
          <Chip label="Платформа для команд и продуктов" color="primary" variant="outlined" sx={{ alignSelf: 'flex-start', fontWeight: 700 }} />
          <Typography
            variant="h2"
            component="h1"
            sx={{
              fontWeight: 900,
              letterSpacing: '-0.03em',
              lineHeight: 1.05,
              fontSize: { xs: '1.65rem', sm: '2.2rem', md: '3.25rem' },
            }}
          >
            Разработка и эксплуатация
            <Box component="span" sx={{ color: 'primary.main', display: 'block' }}>
              в одной связке с API
            </Box>
          </Typography>
          <Typography variant="body1" color="text.secondary" sx={{ lineHeight: 1.75, maxWidth: 720 }}>
            <strong>WaypointMetric</strong> — метрики, логи, BaaS и ingest в одной консоли (не редактор игры). Ядро{' '}
            <strong>Lynx</strong> — <strong>полнофункциональный 2D</strong>-стек с редактором и лаунчером; релизы и манифест —{' '}
            Lynx Cloud и эта консоль. Клиент Lynx — ключевой сценарий; ваш серверный стек может быть любым.
          </Typography>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} sx={{ pt: 1 }}>
            <Button component={RouterLink} to="/register?plan=pro" variant="contained" size="large" startIcon={<RocketLaunch />}>
              Workspace Pro
            </Button>
            <Button component={RouterLink} to="/register?plan=basic" variant="outlined" size="large" startIcon={<Email />}>
              Старт Basic
            </Button>
            <Button component="a" href={TELEGRAM} target="_blank" rel="noreferrer" variant="text" size="large">
              Team / Enterprise
            </Button>
          </Stack>
        </Stack>

        <Typography variant="overline" sx={{ fontWeight: 800, letterSpacing: '0.12em', color: 'text.secondary', display: 'block', mb: 2 }}>
          Три опоры продукта
        </Typography>
        <Grid container spacing={2} sx={{ mb: 5 }}>
          {pillars.map((p) => (
            <Grid item xs={12} md={4} key={p.title}>
              <Paper
                elevation={0}
                sx={(t) => ({
                  p: 2.5,
                  height: '100%',
                  borderRadius: 3,
                  border: `1px solid ${t.palette.divider}`,
                  transition: 'border-color 0.2s, box-shadow 0.2s',
                  '&:hover': {
                    borderColor: alpha(t.palette.primary.main, 0.45),
                    boxShadow: `0 12px 40px ${alpha(t.palette.primary.main, 0.08)}`,
                  },
                })}
              >
                <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 1.5, color: 'primary.main' }}>
                  {p.icon}
                  <Box>
                    <Typography variant="h6" sx={{ fontWeight: 800, lineHeight: 1.2 }}>
                      {p.title}
                    </Typography>
                    <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600 }}>
                      {p.subtitle}
                    </Typography>
                  </Box>
                </Stack>
                <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.7 }}>
                  {p.body}
                </Typography>
              </Paper>
            </Grid>
          ))}
        </Grid>

        <Grid container spacing={3} sx={{ mb: 5 }} alignItems="stretch">
          <Grid item xs={12} md={7}>
            <Paper
              elevation={0}
              sx={(t) => ({
                p: 2.5,
                borderRadius: 3,
                border: `1px solid ${t.palette.divider}`,
                height: '100%',
              })}
            >
              <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                <Terminal color="primary" />
                <Typography variant="h6" sx={{ fontWeight: 800 }}>
                  Первый ingest за минуту
                </Typography>
              </Stack>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2, lineHeight: 1.65 }}>
                После регистрации создайте API-ключ в кабинете и отправьте батч. Полный контракт — в OpenAPI и в разделе «Документация».
              </Typography>
              <Box
                component="pre"
                sx={(t) => ({
                  m: 0,
                  p: 2,
                  borderRadius: 2,
                  fontSize: '0.75rem',
                  lineHeight: 1.5,
                  overflow: 'auto',
                  fontFamily: 'ui-monospace, monospace',
                  bgcolor: t.palette.mode === 'dark' ? alpha('#000', 0.35) : alpha(t.palette.grey[900], 0.06),
                  border: `1px solid ${t.palette.divider}`,
                })}
              >
                {curlExample}
              </Box>
              <Button component={RouterLink} to="/docs" variant="outlined" sx={{ mt: 2 }} startIcon={<MenuBook />}>
                Открыть документацию
              </Button>
            </Paper>
          </Grid>
          <Grid item xs={12} md={5}>
            <Paper
              elevation={0}
              sx={(t) => ({
                p: 2.5,
                borderRadius: 3,
                height: '100%',
                border: `2px solid ${alpha(t.palette.primary.main, 0.35)}`,
                background: alpha(t.palette.primary.main, 0.06),
              })}
            >
              <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 2 }}>
                <Security color="primary" />
                <Typography variant="h6" sx={{ fontWeight: 800 }}>
                  Коммерция и доверие
                </Typography>
              </Stack>
              <Stack spacing={1.25}>
                {[
                  'Планы Basic / Pro — понятный вход и масштаб для команд.',
                  'Биллинг: демо или Stripe на стороне API — без скрытых списаний в интерфейсе.',
                  'Роли и разграничение: staff / платформа Lynx (роль nexus в API) / обычный пользователь.',
                  'Публичный манифест артефактов и политики версий — для контролируемых выкладок.',
                ].map((line) => (
                  <Stack direction="row" spacing={1} alignItems="flex-start" key={line}>
                    <CheckCircle color="primary" sx={{ fontSize: 20, mt: 0.15, flexShrink: 0 }} />
                    <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.65 }}>
                      {line}
                    </Typography>
                  </Stack>
                ))}
              </Stack>
            </Paper>
          </Grid>
        </Grid>

        <Typography variant="overline" sx={{ fontWeight: 800, letterSpacing: '0.12em', color: 'text.secondary', display: 'block', mb: 2 }}>
          Ориентиры для рынка РФ
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2, lineHeight: 1.75, maxWidth: 800 }}>
          Смысловые цели для команд на территории России: доверие, наглядная эксплуатация, локализация, договор и
          интеграции. Юридические режимы и сертификации — в рамках Team / Enterprise.
        </Typography>
        <Grid container spacing={2} sx={{ mb: 5 }}>
          {rfProductPillars.map((p) => (
            <Grid item xs={12} sm={6} md={4} key={p.title}>
              <Paper
                elevation={0}
                sx={(t) => ({
                  p: 2,
                  height: '100%',
                  borderRadius: 3,
                  border: `1px solid ${t.palette.divider}`,
                })}
              >
                <Stack direction="row" spacing={1.25} alignItems="flex-start">
                  <Box sx={{ color: 'primary.main', pt: 0.25 }}>{p.icon}</Box>
                  <Box>
                    <Typography variant="subtitle1" sx={{ fontWeight: 800, mb: 0.75 }}>
                      {p.title}
                    </Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.65 }}>
                      {p.body}
                    </Typography>
                  </Box>
                </Stack>
              </Paper>
            </Grid>
          ))}
        </Grid>

        <Typography variant="h5" sx={{ fontWeight: 800, mb: 2, letterSpacing: '-0.02em' }}>
          Тарифы
        </Typography>
        <Grid container spacing={2} sx={{ mb: 4 }}>
          {[
            {
              name: 'Basic',
              tag: 'Старт',
              highlight: false,
              lines: ['Ingest и обзорные дашборды', 'Онбординг: облако или свой сервер', 'Базовые лимиты модулей'],
              to: '/register?plan=basic',
              btn: 'Регистрация Basic',
              variant: 'outlined' as const,
            },
            {
              name: 'Pro',
              tag: 'Команды',
              highlight: true,
              lines: ['Расширенные лимиты Git и хранилища', 'Realtime и несколько сценариев аренды', 'Приоритет для продакшена'],
              to: '/register?plan=pro',
              btn: 'Регистрация Pro',
              variant: 'contained' as const,
            },
            {
              name: 'Team',
              tag: 'Договор',
              highlight: false,
              lines: ['Индивидуальные лимиты и SLA', 'Онбординг под ваш процесс', 'Интеграции и приоритет в дорожной карте'],
              to: TELEGRAM,
              external: true,
              btn: 'Обсудить в Telegram',
              variant: 'outlined' as const,
            },
          ].map((tier) => (
            <Grid item xs={12} md={4} key={tier.name}>
              <Paper
                elevation={0}
                sx={(t) => ({
                  p: 2.5,
                  height: '100%',
                  display: 'flex',
                  flexDirection: 'column',
                  borderRadius: 3,
                  border:
                    tier.highlight
                      ? `2px solid ${t.palette.primary.main}`
                      : `1px solid ${t.palette.divider}`,
                  bgcolor: tier.highlight ? alpha(t.palette.primary.main, 0.07) : 'transparent',
                })}
              >
                <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 1 }}>
                  <Typography variant="h6" sx={{ fontWeight: 800 }}>
                    {tier.name}
                  </Typography>
                  <Chip size="small" label={tier.tag} color={tier.highlight ? 'primary' : 'default'} variant={tier.highlight ? 'filled' : 'outlined'} />
                </Stack>
                <Stack spacing={1} sx={{ flex: 1, mb: 2 }}>
                  {tier.lines.map((l) => (
                    <Typography key={l} variant="body2" color="text.secondary" sx={{ lineHeight: 1.6 }}>
                      · {l}
                    </Typography>
                  ))}
                </Stack>
                <Button
                  component={tier.external ? 'a' : RouterLink}
                  href={tier.external ? tier.to : undefined}
                  to={tier.external ? undefined : tier.to}
                  target={tier.external ? '_blank' : undefined}
                  rel={tier.external ? 'noreferrer' : undefined}
                  variant={tier.variant}
                  fullWidth
                  size="large"
                >
                  {tier.btn}
                </Button>
              </Paper>
            </Grid>
          ))}
        </Grid>

        <Paper
          elevation={0}
          sx={(t) => ({
            p: 3,
            borderRadius: 3,
            mb: 4,
            border: `1px dashed ${alpha(t.palette.divider, 0.9)}`,
          })}
        >
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ xs: 'flex-start', sm: 'center' }} justifyContent="space-between">
            <Stack direction="row" spacing={1.5} alignItems="center">
              <Groups color="primary" sx={{ fontSize: 40 }} />
              <Box>
                <Typography variant="subtitle1" sx={{ fontWeight: 800 }}>
                  Дорожная карта: среда воспроизведения
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.65 }}>
                  Запись и replay ingest, шаринг контекста отладки и контракт-тесты против API — логичное продолжение
                  Ingest Lab. Напишите, какой сценарий критичен для вашей команды — приоритизируем вместе.
                </Typography>
              </Box>
            </Stack>
            <Button component="a" href={TELEGRAM} target="_blank" rel="noreferrer" variant="contained" color="secondary">
              Влиять на roadmap
            </Button>
          </Stack>
        </Paper>

        <Divider sx={{ my: 3 }} />

        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} justifyContent="space-between" alignItems={{ xs: 'flex-start', sm: 'center' }}>
          <Typography variant="body2" color="text.secondary">
            Waypoint · платформа поверх вашего API. Клиент Lynx — пример полного цикла автора игр.
          </Typography>
          <Stack direction="row" spacing={2}>
            <Link component={RouterLink} to="/" underline="hover" fontWeight={600}>
              Главная
            </Link>
            <Link component={RouterLink} to="/docs" underline="hover" fontWeight={600}>
              Docs
            </Link>
            <Link component={RouterLink} to="/dashboard/billing" underline="hover" fontWeight={600}>
              Биллинг в кабинете
            </Link>
          </Stack>
        </Stack>
      </Container>
    </Box>
  );
}
