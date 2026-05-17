import React from 'react';
import {
  Box,
  Container,
  Paper,
  Stack,
  Typography,
  Link as MuiLink,
  Accordion,
  AccordionSummary,
  AccordionDetails,
  Chip,
  Divider,
} from '@mui/material';
import { ExpandMore } from '@mui/icons-material';
import { Link as RouterLink } from 'react-router-dom';
import { alpha } from '@mui/material/styles';

type ModuleSection = {
  id: string;
  title: string;
  chips?: { label: string; color?: 'default' | 'primary' | 'secondary' }[];
  summary: string;
  points: string[];
  routes?: { label: string; to: string }[];
};

const MODULES: ModuleSection[] = [
  {
    id: 'start',
    title: 'Начало работы, API и доступ',
    chips: [{ label: 'все пользователи', color: 'default' }],
    summary:
      'Как панель достукает бэкенд, какие бывают роли и как войти в том числе через Lynx Auth.',
    points: [
      'Веб-консоль ходит в API по префиксу /api того же сайта (прокси). Клиент Lynx в поле «URL сервера» указывает полный адрес API, например https://api.example.com.',
      'Сессия в браузере: cookie HttpOnly после входа; для CORS в проде нужны точные origin в настройках сервера.',
      'Роли: user — проекты, метрики, модули в рамках тарифа; admin — операции администратора после активации ключа; nexus — расширенный доступ платформы (версии ядра Lynx, ключи и т.д.).',
      'Вход через приложение Lynx: страница /auth/nexus, deep link nexus://nexus-auth (совместимость схемы) и одноразовый код в приложении.',
    ],
    routes: [
      { label: 'Lynx Auth', to: '/auth/nexus' },
      { label: 'Обычный вход', to: '/login' },
    ],
  },
  {
    id: 'workspace',
    title: 'Workspace и онбординг',
    chips: [{ label: 'первый запуск', color: 'primary' }],
    summary: 'Выбор аренды облака или своего сервера, план Basic/Pro и завершение настройки.',
    points: [
      'Раздел Setup задаёт режим: аренда ресурсов у платформы или подключение своего сервера.',
      'Пока setup не завершён, основная навигация кабинета скрыта; отображается акцентный пункт настройки.',
      'План Pro и расширенные возможности могут требовать роли admin/nexus или успешной оплаты — см. подсказки в интерфейсе.',
    ],
    routes: [{ label: 'Настройка workspace', to: '/workspace/setup' }],
  },
  {
    id: 'dashboard',
    title: 'Dashboard (обзор)',
    chips: [{ label: 'после setup', color: 'default' }],
    summary: 'Сводка статусов, загрузки и ключевых метрик по workspace.',
    points: [
      'Центральная точка после входа: виджеты обзора зависят от подключённых модулей и прав.',
      'Служит быстрым переходом к проблемным зонам (ingest, API, аренда).',
    ],
    routes: [{ label: 'Обзор', to: '/dashboard/overview' }],
  },
  {
    id: 'git',
    title: 'Git Workspace',
    chips: [{ label: 'после setup', color: 'default' }],
    summary: 'Работа с репозиториями и лимитами хранения в контексте проекта.',
    points: [
      'Привязка репозиториев, просмотр состояния и операций в рамках выданных лимитов.',
      'Детали коммитов и веток зависят от конфигурации сервера и прав пользователя.',
    ],
    routes: [{ label: 'Git', to: '/dashboard/git' }],
  },
  {
    id: 'metrics',
    title: 'WaypointMetric и Ingest Lab',
    chips: [{ label: 'ingest', color: 'primary' }],
    summary: 'Приём телеметрии и логов; часть WaypointMetric, не редактор ядра Lynx.',
    points: [
      'Внешние сервисы шлют данные с заголовком X-API-Key на POST /waypoint/ingest (на панели путь через /api).',
      'Ключ ingest приходит при регистрации/логине и может отображаться в профиле и рабочем пространстве.',
      'Ingest Lab — ручные прогоны и диагностика приёма без деплоя отдельных утилит.',
    ],
    routes: [
      { label: 'WaypointMetric — главная', to: '/dashboard/waypoint' },
      { label: 'Ingest Lab', to: '/dashboard/ingest-lab' },
    ],
  },
  {
    id: 'testing',
    title: 'Тестирование модулей',
    chips: [{ label: 'нужен сервер', color: 'secondary' }],
    summary: 'Прогоны кодовых баз и сравнение результатов.',
    points: [
      'Доступен при подключённом сервере или режиме аренды Pro (замок в меню снимается после связи с сервером).',
      'Модульные прогоны запускаются на стороне API; UI показывает статусы и артефакты.',
      'Сравнение прогонов — отдельный экран для диффа метрик и выводов.',
    ],
    routes: [
      { label: 'Тестирование', to: '/dashboard/module-testing' },
      { label: 'Сравнение', to: '/dashboard/module-testing/compare' },
    ],
  },
  {
    id: 'postgres',
    title: 'PostgreSQL',
    chips: [{ label: 'нужен сервер', color: 'secondary' }],
    summary: 'Запросы к данным и схема в безопасном режиме.',
    points: [
      'Работа с БД через API консоли; сырой SQL и объём выдачи регулируются политикой сервера.',
      'ER-схема и отчёты помогают ориентироваться в таблицах проекта.',
    ],
    routes: [{ label: 'База данных', to: '/dashboard/database' }],
  },
  {
    id: 'graphics',
    title: 'Графика',
    chips: [{ label: 'после setup', color: 'default' }],
    summary: 'Связка с 2D-ядром Lynx: цель — полный визуальный контур и удобная отладка.',
    points: [
      'Продуктовая цель движка — полнофункциональный 2D-стек (сцена, сущности, тайлмапы, ассеты) с последовательным UI редактора и клиента.',
      'Раздел в кабинете — для отладки витрин и связки с движком/клиентом (зависит от версии API).',
    ],
    routes: [{ label: 'Графика', to: '/dashboard/graphics' }],
  },
  {
    id: 'apihub',
    title: 'API',
    chips: [{ label: 'нужен сервер', color: 'secondary' }],
    summary: 'Сводка эндпоинтов и статусов сервисов.',
    points: [
      'Хаб помогает быстро проверить доступность групп маршрутов и документации.',
      'Полезен при интеграции ботов, backend и мобильных клиентов на общий Postgres/API.',
    ],
    routes: [{ label: 'API Hub', to: '/dashboard/api' }],
  },
  {
    id: 'projects',
    title: 'Проекты и ассеты',
    chips: [{ label: 'после setup', color: 'default' }],
    summary: 'Облачные проекты и файлы контента.',
    points: [
      'Projects — список проектов, владельцы, видимость и облачные операции.',
      'Assets — управление ассетами в привязке к проектам (зависит от ролей).',
    ],
    routes: [
      { label: 'Проекты', to: '/dashboard/projects' },
      { label: 'Ассеты', to: '/dashboard/assets' },
    ],
  },
  {
    id: 'settings',
    title: 'Настройки и биллинг',
    chips: [{ label: 'аккаунт', color: 'default' }],
    summary: 'Профиль, ключи realm, подписка.',
    points: [
      'Профиль пользователя, смена параметров, привязка ролей nexus/metric через ключи активации.',
      'Биллинг: оформление плана; без настроенного Stripe на сервере возможен демо-режим.',
    ],
    routes: [
      { label: 'Настройки', to: '/dashboard/settings' },
      { label: 'Биллинг', to: '/dashboard/billing' },
    ],
  },
  {
    id: 'admin',
    title: 'Администрирование (роль admin+)',
    chips: [{ label: 'admin', color: 'primary' }],
    summary: 'Пользователи, инфраструктура, логи, задачи и интеграции.',
    points: [
      'Users — пользователи платформы и роли.',
      'Server Rent (Instances) — арендуемые и подключённые инстансы.',
      'Realtime — операции над realtime-слоем (комнаты, состояние).',
      'Ядро Lynx (релизы) — политика манифеста и recommended version; для части действий нужна роль nexus в API (см. Lynx Cloud).',
      'Logs — просмотр серверных логов приложения.',
      'Jobs — фоновые и периодические задачи.',
      'AI Analysis — сценарии анализа данных (если включено).',
      'Журнал регистраций — аудит заявок и регистраций.',
      'Admin keys — выпуск ключей admin/nexus.',
      'VK-бот — статус и параметры интеграции ВКонтакте.',
    ],
    routes: [
      { label: 'Пользователи', to: '/dashboard/users' },
      { label: 'Instances', to: '/dashboard/instances' },
      { label: 'Realtime', to: '/dashboard/realtime' },
      { label: 'Ядро Lynx (релизы)', to: '/dashboard/lynx-cloud/engine' },
      { label: 'Логи', to: '/dashboard/logs' },
      { label: 'Jobs', to: '/dashboard/jobs' },
      { label: 'AI', to: '/dashboard/ai' },
      { label: 'Журнал регистраций', to: '/dashboard/registration-log' },
      { label: 'Ключи админа', to: '/dashboard/admin-keys' },
      { label: 'VK-бот', to: '/dashboard/vk-bot' },
    ],
  },
];

export default function Docs() {
  return (
    <Box sx={{ bgcolor: 'background.default', minHeight: '100vh', py: { xs: 3, md: 5 } }}>
      <Container maxWidth="md">
        <Stack spacing={1} sx={{ mb: 3 }}>
          <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.02em' }}>
            Документация WaypointMetric
          </Typography>
          <Typography variant="body1" color="text.secondary" sx={{ lineHeight: 1.65, maxWidth: 720 }}>
            Ядро <strong>Lynx</strong> — <strong>полнофункциональный 2D</strong>-стек с редактором и лаунчером; эта веб-консоль —{' '}
            <strong>WaypointMetric</strong> (метрики, логи, BaaS, AI-ассистент), отдельно от студийного редактора и от политики
            релизов (Lynx Cloud / «Ядро Lynx»). Ниже — модули, доступ и API.
          </Typography>
        </Stack>

        <Paper
          elevation={0}
          sx={(t) => ({
            p: { xs: 2, sm: 2.5 },
            mb: 3,
            borderRadius: 2,
            border: `1px solid ${t.palette.divider}`,
            bgcolor: alpha(t.palette.primary.main, 0.04),
          })}
        >
          <Typography variant="subtitle2" sx={{ fontWeight: 700, mb: 1, color: 'primary.main' }}>
            Быстрые факты
          </Typography>
          <Stack component="ul" sx={{ m: 0, pl: 2.5, color: 'text.secondary', typography: 'body2', lineHeight: 1.65 }}>
            <li>
              API в браузере: префикс <Box component="code" sx={{ bgcolor: 'action.hover', px: 0.5, borderRadius: 0.5 }}>/api</Box>{' '}
              на том же хосте, что и панель.
            </li>
            <li>
              Ingest: <Box component="code" sx={{ bgcolor: 'action.hover', px: 0.5, borderRadius: 0.5 }}>X-API-Key</Box> и{' '}
              <Box component="code" sx={{ bgcolor: 'action.hover', px: 0.5, borderRadius: 0.5 }}>POST …/waypoint/ingest</Box>.
            </li>
            <li>Часть пунктов меню с иконкой замка активируется после подключения сервера в Setup workspace.</li>
          </Stack>
        </Paper>

        <Typography variant="overline" sx={{ fontWeight: 700, letterSpacing: '0.12em', color: 'text.secondary', display: 'block', mb: 1.5 }}>
          Модули платформы
        </Typography>

        <Stack spacing={0} sx={{ borderRadius: 2, overflow: 'hidden', border: (t) => `1px solid ${t.palette.divider}` }}>
          {MODULES.map((m, index) => (
            <Accordion
              key={m.id}
              disableGutters
              elevation={0}
              defaultExpanded={index === 0}
              sx={(t) => ({
                '&:before': { display: 'none' },
                borderBottom: index < MODULES.length - 1 ? `1px solid ${t.palette.divider}` : 'none',
                bgcolor: 'background.paper',
                '&.Mui-expanded': { margin: 0 },
              })}
            >
              <AccordionSummary
                expandIcon={<ExpandIcon />}
                sx={(t) => ({
                  px: 2,
                  py: 1.25,
                  minHeight: 56,
                  '& .MuiAccordionSummary-content': { my: 1, alignItems: 'flex-start', gap: 1 },
                  '&:hover': { bgcolor: alpha(t.palette.primary.main, 0.04) },
                })}
              >
                <Box sx={{ flex: 1, minWidth: 0 }}>
                  <Typography sx={{ fontWeight: 700, fontSize: '1rem', mb: 0.35 }}>{m.title}</Typography>
                  <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.5 }}>
                    {m.summary}
                  </Typography>
                  {!!m.chips?.length && (
                    <Stack direction="row" gap={0.75} flexWrap="wrap" sx={{ mt: 1 }}>
                      {m.chips.map((c) => (
                        <Chip key={c.label} label={c.label} size="small" color={c.color || 'default'} variant="outlined" />
                      ))}
                    </Stack>
                  )}
                </Box>
              </AccordionSummary>
              <AccordionDetails sx={{ px: 2, pt: 0, pb: 2.5, bgcolor: (t) => alpha(t.palette.background.default, 0.5) }}>
                <Stack component="ul" spacing={1.25} sx={{ m: 0, pl: 2, typography: 'body2', color: 'text.secondary', lineHeight: 1.65 }}>
                  {m.points.map((p, i) => (
                    <li key={`${m.id}-${i}`}>{p}</li>
                  ))}
                </Stack>
                {!!m.routes?.length && (
                  <>
                    <Divider sx={{ my: 2 }} />
                    <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600, display: 'block', mb: 1 }}>
                      Переходы в консоли
                    </Typography>
                    <Stack direction="row" flexWrap="wrap" gap={1}>
                      {m.routes.map((r) => (
                        <MuiLink key={r.to} component={RouterLink} to={r.to} underline="hover" sx={{ fontWeight: 600 }}>
                          {r.label}
                        </MuiLink>
                      ))}
                    </Stack>
                  </>
                )}
              </AccordionDetails>
            </Accordion>
          ))}
        </Stack>

        <Divider sx={{ my: 4 }} />
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems={{ sm: 'center' }} justifyContent="space-between">
          <MuiLink component={RouterLink} to="/" underline="hover" sx={{ fontWeight: 600 }}>
            ← На главную
          </MuiLink>
          <MuiLink component={RouterLink} to="/dashboard/overview" underline="hover" sx={{ fontWeight: 600 }}>
            В кабинет (после входа) →
          </MuiLink>
        </Stack>
      </Container>
    </Box>
  );
}

function ExpandIcon() {
  return <ExpandMore sx={{ color: 'primary.main' }} />;
}
