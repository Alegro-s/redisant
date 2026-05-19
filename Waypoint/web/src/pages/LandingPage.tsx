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
  Drawer,
  IconButton,
  Link,
  Menu,
  MenuItem,
  Divider,
  Tooltip,
} from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';
import {
  Email,
  Login,
  CheckCircle,
  Insights,
  RocketLaunch,
  Menu as MenuIcon,
  ChatBubbleOutline,
  InstallMobile,
  TableChart,
  Computer,
  VpnKey,
  LightbulbOutlined,
  MenuBook,
  MoreHoriz,
  Gavel,
  MonitorHeart,
  Language,
  AccountBalance,
  Hub,
} from '@mui/icons-material';
import { ModuleFeatureCard } from '../components/common/ModuleFeatureCard';
import { PwaInstallButton } from '../components/common/PwaInstallButton';
import { LINKS } from '../marketing/links';


const LANDING_COL_MAX = 960;

const MODULE_CARD_MIN_PX = 268;

const moduleLinks = [
  {
    title: 'Облачная база',
    to: '/register?plan=basic',
    icon: <TableChart fontSize="small" />,
    description: (
      <>
        <strong>Таблицы, файлы и запросы</strong> в PostgreSQL — без отдельного сервера для старта.
      </>
    ),
  },
  {
    title: 'Метрики и события',
    to: '/register?plan=basic',
    icon: <Insights fontSize="small" />,
    description: (
      <>
        <strong>Сбор событий</strong> из приложений, ботов и сервисов — сводки в кабинете.
      </>
    ),
  },
  {
    title: 'Waypoint Desktop',
    to: '/register?plan=basic',
    icon: <Computer fontSize="small" />,
    description: (
      <>
        <strong>Привязка программы на ПК</strong> к вашему облаку: терминал и работа рядом с Metric.
      </>
    ),
  },
  {
    title: 'Ключи приложений',
    to: '/register?plan=basic',
    icon: <VpnKey fontSize="small" />,
    description: (
      <>
        <strong>Ключи для ingest и API</strong> — выдаются после настройки облака в кабинете.
      </>
    ),
  },
];

const modulesRow1 = moduleLinks.slice(0, 2);
const modulesRow2 = moduleLinks.slice(2, 4);

const rfProductPillars = [
  {
    title: 'Доверие и соответствие',
    icon: <Gavel sx={{ fontSize: 28 }} />,
    body:
      'Прозрачная модель размещения данных (в т.ч. в контуре РФ), работа с ДПО и согласиями, журналы доступа, варианты on-prem или выделенного контура без «всё в одном зарубежном облаке». Для крупного B2B это часто условие закупки observability.',
  },
  {
    title: 'Кто нагружает сервер',
    icon: <MonitorHeart sx={{ fontSize: 28 }} />,
    body:
      'Не только сырые метрики: готовые дашборды — топ процессов и контейнеров, разбивка по сервисам, алерты по диску, памяти и load, интеграция с systemd и Docker. Скрипты хоста и ingest — шаг к этой картине.',
  },
  {
    title: 'Локализация и поддержка',
    icon: <Language sx={{ fontSize: 28 }} />,
    body:
      'Русский интерфейс и документация первого уровня, SLA и канал поддержки в часовом поясе РФ, инструкции для администраторов инфраструктуры, а не только для разработчиков.',
  },
  {
    title: 'Платежи и договоры',
    icon: <AccountBalance sx={{ fontSize: 28 }} />,
    body:
      'Оплата в рублях по счёту, ЭДО, типовой договор — для многих команд важнее очередной мелкой фичи в API.',
  },
  {
    title: 'Интеграции под местный стек',
    icon: <Hub sx={{ fontSize: 28 }} />,
    body:
      'Уведомления в привычных каналах (в т.ч. VK и Telegram), почта у российских провайдеров, выгрузка логов в S3-совместимое хранилище в РФ — по мере развития продукта.',
  },
];

export default function LandingPage() {
  const [mobileOpen, setMobileOpen] = React.useState(false);
  const [moreMenuAnchor, setMoreMenuAnchor] = React.useState<null | HTMLElement>(null);
  const moreMenuOpen = Boolean(moreMenuAnchor);
  const closeMoreMenu = () => setMoreMenuAnchor(null);

  return (
    <Box
      sx={{
        minHeight: '100vh',
        overflowX: 'hidden',
        background: (t) => `linear-gradient(160deg, ${t.palette.background.default} 0%, ${t.palette.background.paper} 100%)`,
        position: 'relative',
      }}
    >
      <Box
        sx={(t) => ({
          position: 'absolute',
          top: -80,
          left: -80,
          width: 260,
          height: 260,
          borderRadius: '50%',
          background: `${t.palette.primary.main}24`,
          filter: 'blur(40px)',
        })}
      />
      <Box
        sx={(t) => ({
          position: 'absolute',
          bottom: -100,
          right: -50,
          width: 300,
          height: 300,
          borderRadius: '50%',
          background: `${t.palette.primary.main}14`,
          filter: 'blur(45px)',
        })}
      />

      <Box
        sx={(t) => ({
          position: 'sticky',
          top: 0,
          left: 0,
          right: 0,
          zIndex: 1200,
          borderBottom: `1px solid ${t.palette.divider}`,
          backdropFilter: 'blur(14px)',
          backgroundColor: `${t.palette.background.paper}e8`,
          transition: 'background-color 0.2s ease, border-color 0.2s ease',
        })}
      >
        <Container maxWidth="lg">
          <Stack
            direction="row"
            alignItems="center"
            justifyContent="space-between"
            sx={{ py: 1.25, px: { xs: 0.5, sm: 0 } }}
          >
            <Stack direction="row" spacing={1.2} alignItems="center" component={RouterLink} to="/" sx={{ textDecoration: 'none', color: 'inherit' }}>
              <Box
                component="img"
                src="/favicon.svg"
                alt=""
                sx={{ width: 32, height: 32, display: 'block' }}
              />
              <Typography variant="h6" sx={{ fontWeight: 800, letterSpacing: '-0.01em' }}>
                Waypoint Metric
              </Typography>
            </Stack>
            <Stack direction="row" spacing={1} alignItems="center" sx={{ display: { xs: 'none', md: 'flex' }, flexWrap: 'nowrap' }}>
              <Button
                component={RouterLink}
                to="/platform"
                variant="text"
                size="medium"
                sx={{ fontWeight: 700, whiteSpace: 'nowrap', color: 'primary.main' }}
              >
                Платформа
              </Button>
              <Button
                component={RouterLink}
                to="/login"
                variant="outlined"
                size="medium"
                startIcon={<Login />}
                sx={(t) => ({
                  bgcolor: t.palette.background.default,
                  borderColor: t.palette.divider,
                  whiteSpace: 'nowrap',
                  '&:hover': { borderColor: 'text.secondary', bgcolor: 'action.hover' },
                })}
              >
                Вход
              </Button>
              <Button
                component={RouterLink}
                to="/register"
                variant="contained"
                size="medium"
                startIcon={<Email />}
                sx={{ px: 2.2, whiteSpace: 'nowrap' }}
              >
                Регистрация
              </Button>
              <Tooltip title="Документация, обратная связь, установка" enterDelay={400} placement="bottom">
                <IconButton
                  aria-label="Дополнительно: документация, связь, установка"
                  aria-controls={moreMenuOpen ? 'landing-header-more-menu' : undefined}
                  aria-haspopup="true"
                  aria-expanded={moreMenuOpen ? 'true' : undefined}
                  onClick={(e) => setMoreMenuAnchor(e.currentTarget)}
                  sx={(t) => ({
                    border: `1px solid ${alpha(t.palette.primary.main, 0.5)}`,
                    borderRadius: 2,
                    color: t.palette.primary.main,
                    '&:hover': {
                      bgcolor: alpha(t.palette.primary.main, 0.1),
                      borderColor: t.palette.primary.main,
                    },
                  })}
                >
                  <MoreHoriz />
                </IconButton>
              </Tooltip>
              <Menu
                id="landing-header-more-menu"
                anchorEl={moreMenuAnchor}
                open={moreMenuOpen}
                onClose={closeMoreMenu}
                anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                transformOrigin={{ vertical: 'top', horizontal: 'right' }}
                PaperProps={{
                  elevation: 3,
                  sx: (t) => ({
                    mt: 1,
                    minWidth: 260,
                    borderRadius: 2,
                    border: `1px solid ${alpha(t.palette.primary.main, 0.2)}`,
                  }),
                }}
              >
                <MenuItem
                  component="a"
                  href={LINKS.desktop}
                  onClick={closeMoreMenu}
                  sx={(t) => ({
                    py: 1.25,
                    gap: 1.5,
                    color: t.palette.secondary.main,
                    '&:hover': { bgcolor: alpha(t.palette.secondary.main, 0.1) },
                  })}
                >
                  <RocketLaunch fontSize="small" sx={(t) => ({ color: t.palette.secondary.main })} />
                  Waypoint Desktop (ПК)
                </MenuItem>
                <MenuItem
                  component="a"
                  href={LINKS.club}
                  onClick={closeMoreMenu}
                  sx={(t) => ({
                    py: 1.25,
                    gap: 1.5,
                    color: t.palette.text.secondary,
                    '&:hover': { bgcolor: alpha(t.palette.primary.main, 0.06) },
                  })}
                >
                  <Hub fontSize="small" />
                  Экосистема Waypoint Club
                </MenuItem>
                <MenuItem
                  component={RouterLink}
                  to="/platform"
                  onClick={closeMoreMenu}
                  sx={(t) => ({
                    py: 1.25,
                    gap: 1.5,
                    color: t.palette.secondary.main,
                    '&:hover': { bgcolor: alpha(t.palette.secondary.main, 0.1) },
                  })}
                >
                  <RocketLaunch fontSize="small" sx={(t) => ({ color: t.palette.secondary.main })} />
                  Платформа для разработчиков
                </MenuItem>
                <MenuItem
                  component={RouterLink}
                  to="/docs"
                  onClick={closeMoreMenu}
                  sx={(t) => ({
                    py: 1.25,
                    gap: 1.5,
                    color: t.palette.primary.main,
                    '&:hover': { bgcolor: alpha(t.palette.primary.main, 0.08) },
                  })}
                >
                  <MenuBook fontSize="small" sx={(t) => ({ color: t.palette.primary.main })} />
                  Документация
                </MenuItem>
                <MenuItem
                  component="a"
                  href="https://t.me/AlegroMay"
                  target="_blank"
                  rel="noreferrer"
                  onClick={closeMoreMenu}
                  sx={(t) => ({
                    py: 1.25,
                    gap: 1.5,
                    color: t.palette.primary.main,
                    '&:hover': { bgcolor: alpha(t.palette.primary.main, 0.08) },
                  })}
                >
                  <ChatBubbleOutline fontSize="small" sx={(t) => ({ color: t.palette.primary.main })} />
                  Обратная связь
                </MenuItem>
                <Divider sx={(t) => ({ my: 0.5, borderColor: alpha(t.palette.primary.main, 0.15) })} />
                <Box sx={{ px: 1.5, py: 1, width: '100%' }} onMouseDown={(e) => e.stopPropagation()}>
                  <PwaInstallButton
                    fullWidth
                    color="primary"
                    variant="outlined"
                    size="small"
                    onClick={closeMoreMenu}
                  />
                </Box>
              </Menu>
            </Stack>
            <IconButton sx={{ display: { xs: 'inline-flex', md: 'none' } }} onClick={() => setMobileOpen(true)} aria-label="Меню">
              <MenuIcon />
            </IconButton>
          </Stack>
        </Container>
      </Box>

      <Container maxWidth="lg" sx={{ py: { xs: 2, md: 4 }, position: 'relative' }}>
        <Stack spacing={2} sx={{ textAlign: 'center', maxWidth: LANDING_COL_MAX, mx: 'auto', mb: 5, mt: { xs: 2, md: 3 }, width: '100%' }}>
          <Stack direction="row" spacing={1} flexWrap="wrap" justifyContent="center" alignItems="center" useFlexGap>
            <Chip label="Waypoint Metric · облачный кабинет" color="primary" variant="outlined" sx={{ fontWeight: 600 }} />
            <Chip label="База · метрики · Desktop" color="default" variant="outlined" sx={{ fontWeight: 500 }} />
          </Stack>
          <Typography
            variant="h2"
            component="h1"
            sx={{
              fontWeight: 900,
              letterSpacing: '-0.03em',
              lineHeight: 1.04,
              fontSize: { xs: '1.7rem', sm: '2.15rem', md: '4rem' },
            }}
          >
            Облако для приложений
            <br />
            <Box component="span" sx={{ color: 'primary.main' }}>
              база, метрики и Desktop
            </Box>
          </Typography>
          <Typography variant="body1" color="text.secondary" sx={{ maxWidth: LANDING_COL_MAX, mx: 'auto', lineHeight: 1.72, textAlign: 'center', px: { xs: 0, sm: 0 } }}>
            <strong>Waypoint Metric</strong> — личный кабинет в облаке: PostgreSQL и файлы, сбор метрик, ключи для
            приложений и привязка <strong>Waypoint Desktop</strong> на вашем компьютере. Регистрация → настройка облака →
            работа в понятных разделах без лишней техники в интерфейсе.
          </Typography>

          <Paper
            id="developers"
            elevation={0}
            sx={(t) => ({
              mt: 3,
              p: { xs: 2, sm: 3 },
              borderRadius: 3,
              textAlign: 'left',
              border: `1px solid ${alpha(t.palette.primary.main, 0.35)}`,
              background: `linear-gradient(135deg, ${alpha(t.palette.primary.main, 0.08)} 0%, ${t.palette.background.paper} 55%)`,
            })}
          >
            <Stack direction="row" spacing={1.5} alignItems="center" sx={{ mb: 1.5 }}>
              <Box
                sx={(t) => ({
                  p: 1,
                  borderRadius: 2,
                  display: 'flex',
                  color: 'primary.main',
                  bgcolor: alpha(t.palette.primary.main, 0.12),
                })}
              >
                <RocketLaunch />
              </Box>
              <Box>
                <Typography variant="overline" sx={{ fontWeight: 700, letterSpacing: '0.12em', color: 'primary.main' }}>
                  Для разработчиков
                </Typography>
                <Typography variant="h6" sx={{ fontWeight: 800, lineHeight: 1.2 }}>
                  Для команд и интеграций
                </Typography>
              </Box>
            </Stack>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2, lineHeight: 1.7, maxWidth: 640 }}>
              После входа доступны база, метрики и ключи. Подробные схемы API и расширенные сценарии — в документации и на
              странице платформы для разработчиков.
            </Typography>
            <Grid container spacing={1.5} alignItems="stretch">
              {[
                { title: 'Метрики', sub: 'События и сводки', to: '/register?plan=basic', icon: <Insights fontSize="small" /> },
                { title: 'Документация', sub: 'Подключение и API', to: '/docs', icon: <MenuBook fontSize="small" /> },
                { title: 'Платформа', sub: 'Расширенные возможности', to: '/platform', icon: <Hub fontSize="small" /> },
              ].map((item) => (
                <Grid item xs={12} sm={4} key={item.title} sx={{ display: 'flex' }}>
                  <Paper
                    component={RouterLink}
                    to={item.to}
                    elevation={0}
                    sx={(t) => ({
                      p: 1.75,
                      width: '100%',
                      display: 'flex',
                      flexDirection: 'column',
                      borderRadius: 2,
                      textDecoration: 'none',
                      color: 'inherit',
                      border: `1px solid ${t.palette.divider}`,
                      transition: 'border-color 0.2s, box-shadow 0.2s',
                      '&:hover': {
                        borderColor: t.palette.primary.main,
                        boxShadow: `0 4px 16px ${alpha(t.palette.primary.main, 0.12)}`,
                      },
                    })}
                  >
                    <Stack direction="row" spacing={1} alignItems="flex-start" sx={{ mb: 0.75 }}>
                      <Box sx={{ color: 'primary.main', display: 'flex', flexShrink: 0, mt: 0.15 }}>{item.icon}</Box>
                      <Typography variant="subtitle2" sx={{ fontWeight: 700, lineHeight: 1.3 }}>
                        {item.title}
                      </Typography>
                    </Stack>
                    <Typography variant="caption" color="text.secondary" sx={{ lineHeight: 1.45, mt: 'auto' }}>
                      {item.sub}
                    </Typography>
                  </Paper>
                </Grid>
              ))}
            </Grid>
            <Stack direction="row" sx={{ mt: 2 }}>
              <Button
                component={RouterLink}
                to="/platform"
                variant="contained"
                size="medium"
                startIcon={<RocketLaunch />}
              >
                Платформа для разработчиков
              </Button>
            </Stack>
          </Paper>

          <Stack
            direction={{ xs: 'column', sm: 'row' }}
            spacing={{ xs: 1.5, sm: 1.25 }}
            justifyContent="center"
            alignItems="stretch"
            sx={{ pt: 3, width: '100%' }}
          >
            {[
              { n: '1', label: 'Тариф', sub: 'Basic или Pro' },
              { n: '2', label: 'Аккаунт', sub: 'Регистрация или вход' },
              { n: '3', label: 'Настройка', sub: 'Облако платформы или свой сервер' },
              { n: '4', label: 'Кабинет', sub: 'База, метрики, Desktop, ключи' },
            ].map((s) => (
              <Paper
                key={s.n}
                elevation={0}
                sx={(t) => ({
                  flex: 1,
                  py: 1.5,
                  px: 2,
                  borderRadius: 2,
                  border: `1px solid ${t.palette.divider}`,
                  textAlign: 'center',
                  minWidth: 0,
                })}
              >
                <Typography variant="caption" sx={{ fontWeight: 800, color: 'primary.main', letterSpacing: '0.06em' }}>
                  Шаг {s.n}
                </Typography>
                <Typography variant="subtitle2" sx={{ fontWeight: 700, mt: 0.5, display: 'block' }}>
                  {s.label}
                </Typography>
                <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.25, lineHeight: 1.4 }}>
                  {s.sub}
                </Typography>
              </Paper>
            ))}
          </Stack>

          <Box id="tariffs" sx={{ width: '100%', pt: 2, textAlign: 'left' }}>
            <Typography variant="overline" sx={{ fontWeight: 700, letterSpacing: '0.14em', color: 'text.secondary', display: 'block' }}>
              Шаг 1 — выберите тариф
            </Typography>
            <Grid container spacing={2} sx={{ mt: 1 }}>
              <Grid item xs={12} md={6}>
                <Paper
                  elevation={0}
                  sx={(t) => ({
                    p: 2.75,
                    borderRadius: 3,
                    height: '100%',
                    border: `2px solid ${t.palette.primary.main}`,
                    background: alpha(t.palette.primary.main, 0.06),
                  })}
                >
                  <Stack direction="row" justifyContent="space-between" alignItems="flex-start" sx={{ mb: 1 }}>
                    <Typography variant="h5" sx={{ fontWeight: 800 }}>
                      Basic
                    </Typography>
                    <Chip size="small" label="Старт" color="primary" />
                  </Stack>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 2, lineHeight: 1.65 }}>
                    Для личных приложений и первых интеграций. Облачная база, метрики, ключи и привязка Desktop — в
                    пределах лимитов тарифа.
                  </Typography>
                  <Stack spacing={1} sx={{ mb: 2 }}>
                    {['Облачная база PostgreSQL', 'Метрики и ключи ingest', 'Привязка Waypoint Desktop'].map((x) => (
                      <Stack direction="row" spacing={1} alignItems="center" key={x}>
                        <CheckCircle color="primary" sx={{ fontSize: 18 }} />
                        <Typography variant="body2">{x}</Typography>
                      </Stack>
                    ))}
                  </Stack>
                  <Button
                    component={RouterLink}
                    to="/register?plan=basic"
                    variant="contained"
                    fullWidth
                    size="large"
                    startIcon={<Email />}
                  >
                    Регистрация Basic
                  </Button>
                  <Button component={RouterLink} to="/login?plan=basic" fullWidth sx={{ mt: 1 }} size="small">
                    Уже есть аккаунт — войти с Basic
                  </Button>
                </Paper>
              </Grid>
              <Grid item xs={12} md={6}>
                <Paper
                  elevation={0}
                  sx={(t) => ({
                    p: 2.75,
                    borderRadius: 3,
                    height: '100%',
                    border: `1px solid ${t.palette.divider}`,
                  })}
                >
                  <Stack direction="row" justifyContent="space-between" alignItems="flex-start" sx={{ mb: 1 }}>
                    <Typography variant="h5" sx={{ fontWeight: 800 }}>
                      Pro
                    </Typography>
                    <Chip size="small" label="Команды и нагрузка" variant="outlined" />
                  </Stack>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 2, lineHeight: 1.65 }}>
                    Больше ресурсов облака и расширенные лимиты. Подключение своего сервера и приоритетная поддержка —
                    по договорённости после входа.
                  </Typography>
                  <Stack spacing={1} sx={{ mb: 2 }}>
                    {['Увеличенные лимиты базы и метрик', 'Свой сервер в настройке облака', 'Для команд и продакшена'].map(
                      (x) => (
                        <Stack direction="row" spacing={1} alignItems="center" key={x}>
                          <CheckCircle color="action" sx={{ fontSize: 18 }} />
                          <Typography variant="body2">{x}</Typography>
                        </Stack>
                      ),
                    )}
                  </Stack>
                  <Button
                    component={RouterLink}
                    to="/register?plan=pro"
                    variant="outlined"
                    fullWidth
                    size="large"
                    color="primary"
                    startIcon={<RocketLaunch />}
                  >
                    Регистрация Pro
                  </Button>
                  <Button component={RouterLink} to="/login?plan=pro" fullWidth sx={{ mt: 1 }} size="small">
                    Войти и продолжить с Pro
                  </Button>
                </Paper>
              </Grid>
            </Grid>
          </Box>

          <Paper
            elevation={0}
            sx={(t) => ({
              p: 2.75,
              borderRadius: 3,
              width: '100%',
              textAlign: 'left',
              border: `2px dashed ${alpha(t.palette.primary.main, 0.45)}`,
              background: alpha(t.palette.primary.main, 0.04),
            })}
          >
            <Stack direction="row" spacing={1.5} alignItems="flex-start">
              <Box
                sx={(t) => ({
                  p: 1,
                  borderRadius: 2,
                  color: 'primary.main',
                  bgcolor: alpha(t.palette.primary.main, 0.12),
                  display: 'flex',
                })}
              >
                <LightbulbOutlined />
              </Box>
              <Box sx={{ flex: 1, minWidth: 0 }}>
                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1, flexWrap: 'wrap' }}>
                  <Typography variant="h6" sx={{ fontWeight: 800 }}>
                    Стартап-проект
                  </Typography>
                  <Chip size="small" label="Открытая разработка" color="primary" variant="outlined" />
                </Stack>
                <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.65 }}>
                  Мы наращиваем функции и стабильность на ваших сценариях. Пишите в Telegram — приоритизируем дорожную
                  карту и доводим продукт вместе с ранними пользователями.
                </Typography>
              </Box>
            </Stack>
          </Paper>

          <Box id="rf-product" sx={{ width: '100%', textAlign: 'left', pt: 1, pb: 1 }}>
            <Typography
              variant="overline"
              sx={{ fontWeight: 700, letterSpacing: '0.14em', color: 'text.secondary', display: 'block', mb: 1 }}
            >
              Сильный продукт для команд в РФ
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2, lineHeight: 1.7, maxWidth: 720 }}>
              Ниже — не маркетинговые обещания, а ориентиры дорожной карты: что критично для B2B и госзаказа на территории
              России и как мы к этому приближаемся.
            </Typography>
            <Grid container spacing={2}>
              {rfProductPillars.map((p) => (
                <Grid item xs={12} sm={6} key={p.title}>
                  <Paper
                    elevation={0}
                    sx={(t) => ({
                      p: 2,
                      height: '100%',
                      borderRadius: 2,
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
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 2, lineHeight: 1.5 }}>
              Юридические режимы и сертификации обсуждаются индивидуально (Team / Enterprise).
            </Typography>
          </Box>

          <Stack spacing={3} sx={{ width: '100%', textAlign: 'left', pt: 1 }}>
            <Box>
              <Typography variant="overline" sx={{ fontWeight: 700, letterSpacing: '0.14em', color: 'text.secondary', display: 'block' }}>
                Шаг 2 — аккаунт
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mt: 1, lineHeight: 1.65 }}>
                Зарегистрируйтесь или войдите: выбранный на главной тариф передаётся в онбординг, чтобы сразу показать
                правильные лимиты.
              </Typography>
              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} sx={{ mt: 2 }}>
                <Button component={RouterLink} to="/register?plan=basic" variant="contained" startIcon={<Email />}>
                  Регистрация
                </Button>
                <Button component={RouterLink} to="/login" variant="outlined" startIcon={<Login />}>
                  Вход
                </Button>
              </Stack>
            </Box>
            <Box>
              <Typography variant="overline" sx={{ fontWeight: 700, letterSpacing: '0.14em', color: 'text.secondary', display: 'block' }}>
                Шаг 3 — онбординг
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mt: 1, lineHeight: 1.65 }}>
                После первого входа уточните, что вам нужно: <strong>аренда облака</strong> у платформы или{' '}
                <strong>свой сервер</strong> — от этого зависят подсказки, лимиты и разделы кабинета.
              </Typography>
            </Box>
            <Box>
              <Typography variant="overline" sx={{ fontWeight: 700, letterSpacing: '0.14em', color: 'text.secondary', display: 'block' }}>
                Шаг 4 — кабинет
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mt: 1, lineHeight: 1.65 }}>
                Доступны главная, база, метрики, привязка Desktop и ключи — в соответствии с тарифом и настройкой облака.
              </Typography>
            </Box>
          </Stack>

          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} justifyContent="center" alignItems="center" sx={{ pt: 2 }}>
            <Button
              component={RouterLink}
              to="/register?plan=basic"
              variant="contained"
              size="large"
              sx={{ px: 4 }}
              startIcon={<Email />}
            >
              Начните с Basic
            </Button>
            <Button
              component="a"
              href="https://t.me/AlegroMay"
              target="_blank"
              rel="noreferrer"
              variant="outlined"
              size="large"
              startIcon={<ChatBubbleOutline />}
              sx={(t) => ({
                px: 3.2,
                bgcolor: t.palette.background.default,
                borderColor: t.palette.divider,
                '&:hover': { borderColor: 'text.secondary', bgcolor: 'action.hover' },
              })}
            >
              Написать в Telegram
            </Button>
            <PwaInstallButton variant="contained" size="large" sx={{ px: 3, display: { xs: 'inline-flex', md: 'none' } }}>
              Установить приложение
            </PwaInstallButton>
          </Stack>
          <Typography variant="body2" color="text.secondary" sx={{ textAlign: 'center' }}>
            Уже есть аккаунт?{' '}
            <Link component={RouterLink} to="/login" sx={{ fontWeight: 600 }} underline="hover">
              Войти
            </Link>
            {' · '}
            <Link component={RouterLink} to="/login?plan=pro" sx={{ fontWeight: 600 }} underline="hover">
              Войти (Pro)
            </Link>
          </Typography>
        </Stack>

        <Box sx={{ maxWidth: LANDING_COL_MAX, mx: 'auto', width: '100%', mt: 6 }}>
          <Paper
            elevation={0}
            sx={(t) => ({
              p: { xs: 2, sm: 3 },
              borderRadius: 3,
              mb: 2,
              border: `1px solid ${t.palette.divider}`,
              bgcolor: alpha(t.palette.background.paper, 0.6),
            })}
          >
            <Typography variant="h5" sx={{ fontWeight: 800, mb: 0.75, letterSpacing: '-0.02em', textAlign: 'left' }}>
              Что в кабинете
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2.5, textAlign: 'left', lineHeight: 1.65 }}>
              После регистрации и настройки облака — четыре основных раздела в одном интерфейсе Waypoint Metric.
            </Typography>

          <Grid container spacing={2} sx={{ mb: 2 }} alignItems="stretch">
            {modulesRow1.map((m) => (
              <Grid item xs={12} sm={6} key={m.title} sx={{ display: 'flex' }}>
                <ModuleFeatureCard
                  title={m.title}
                  description={m.description}
                  icon={m.icon}
                  to={m.to}
                  minHeight={MODULE_CARD_MIN_PX}
                />
              </Grid>
            ))}
          </Grid>
          <Grid container spacing={2} sx={{ mb: 2 }} alignItems="stretch">
            {modulesRow2.map((m) => (
              <Grid item xs={12} sm={6} key={m.title} sx={{ display: 'flex' }}>
                <ModuleFeatureCard
                  title={m.title}
                  description={m.description}
                  icon={m.icon}
                  to={m.to}
                  minHeight={MODULE_CARD_MIN_PX}
                />
              </Grid>
            ))}
          </Grid>
          </Paper>
        </Box>

        <Box sx={{ mt: 6, textAlign: 'center', maxWidth: LANDING_COL_MAX, mx: 'auto' }}>
          <Link href="#tariffs" underline="hover" sx={{ fontWeight: 600 }}>
            ↑ К выбору тарифа
          </Link>
        </Box>
      </Container>
      <Drawer anchor="right" open={mobileOpen} onClose={() => setMobileOpen(false)}>
        <Stack sx={{ width: 280, p: 2 }} spacing={1.2}>
          <Typography sx={{ fontWeight: 800, mb: 1 }}>Меню</Typography>
          <Button component="a" href={LINKS.desktop} onClick={() => setMobileOpen(false)} variant="outlined" color="secondary">
            Desktop
          </Button>
          <Button component="a" href={LINKS.club} onClick={() => setMobileOpen(false)} variant="outlined">
            Waypoint Club
          </Button>
          <Button component={RouterLink} to="/platform" onClick={() => setMobileOpen(false)} variant="outlined" color="secondary">
            Платформа
          </Button>
          <Button component={RouterLink} to="/docs" onClick={() => setMobileOpen(false)} startIcon={<MenuBook />}>
            Документация
          </Button>
          <Button component={RouterLink} to="/login" onClick={() => setMobileOpen(false)} startIcon={<Login />}>
            Вход
          </Button>
          <Button component={RouterLink} to="/register" onClick={() => setMobileOpen(false)} variant="contained" startIcon={<Email />}>
            Регистрация
          </Button>
          <Button
            component="a"
            href="https://t.me/AlegroMay"
            target="_blank"
            rel="noreferrer"
            onClick={() => setMobileOpen(false)}
            startIcon={<ChatBubbleOutline />}
          >
            Обратная связь
          </Button>
          <PwaInstallButton fullWidth variant="contained" startIcon={<InstallMobile />} onClick={() => setMobileOpen(false)} />
        </Stack>
      </Drawer>
    </Box>
  );
}
