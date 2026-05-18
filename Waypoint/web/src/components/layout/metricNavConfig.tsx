import React from 'react';
import {
  Cable,
  Computer,
  Dashboard,
  HomeWork,
  Hub,
  QueryStats,
  Settings,
  SmartToy,
  AccountBalanceWallet,
  CloudQueue,
  Storage,
} from '@mui/icons-material';
import type { CabinetMode } from '../../app/contexts/CabinetModeContext';

export type MetricNavItem = {
  text: string;
  icon: React.ReactNode;
  path: string;
  requiresServer?: boolean;
  secondary?: string;
};

export type MetricNavSection = { title: string; items: MetricNavItem[] };

/** Основное меню — облако дополняет Desktop (привязка, метрики, ключи). */
export const metricPrimarySections: MetricNavSection[] = [
  {
    title: 'Облако',
    items: [
      { text: 'Рабочий стол', icon: <HomeWork />, path: '/dashboard', secondary: 'Быстрый доступ' },
      { text: 'Обзор', icon: <Dashboard />, path: '/dashboard/overview', secondary: 'Сводка и графики' },
      {
        text: 'Метрики',
        icon: <QueryStats />,
        path: '/dashboard/ingest-lab/summary',
        secondary: 'События и ingest',
      },
      {
        text: 'Waypoint Desktop',
        icon: <Computer />,
        path: '/dashboard/settings/devices',
        secondary: 'Привязка ПК · синхронизация',
      },
      { text: 'Помощник', icon: <SmartToy />, path: '/dashboard/business/ai', secondary: 'Вопросы по данным' },
      {
        text: 'База данных',
        icon: <Storage />,
        path: '/dashboard/database',
        requiresServer: true,
        secondary: 'Таблицы · SQL · ER · API',
      },
    ],
  },
  {
    title: 'Аккаунт',
    items: [
      { text: 'API и ключи', icon: <Cable />, path: '/dashboard/connect', secondary: 'SDK · интеграции' },
      { text: 'Настройки', icon: <Settings />, path: '/dashboard/settings' },
      { text: 'Биллинг', icon: <AccountBalanceWallet />, path: '/dashboard/billing' },
    ],
  },
];

/** Серверная инфраструктура — в приложении это Docker/терминал локально. */
export const metricInfraSections: MetricNavSection[] = [
  {
    title: 'Инфраструктура',
    items: [
      {
        text: 'Lynx Cloud',
        icon: <Hub />,
        path: '/dashboard/lynx-cloud',
        requiresServer: true,
        secondary: 'Проекты · сборки',
      },
      { text: 'Ingest Lab', icon: <QueryStats />, path: '/dashboard/ingest-lab', secondary: 'Отправка · журнал' },
    ],
  },
];

export function navSectionsForMode(mode: CabinetMode): MetricNavSection[] {
  if (mode === 'developer') {
    return [...metricPrimarySections, ...metricInfraSections];
  }
  return metricPrimarySections;
}

export const metricRailItems = [
  {
    icon: <HomeWork />,
    path: '/dashboard',
    label: 'Стол',
    match: (p: string) => p === '/dashboard',
  },
  {
    icon: <Dashboard />,
    path: '/dashboard/overview',
    label: 'Обзор',
    match: (p: string) => p === '/dashboard/overview',
  },
  {
    icon: <QueryStats />,
    path: '/dashboard/ingest-lab/summary',
    label: 'Метрики',
    match: (p: string) => p.startsWith('/dashboard/ingest-lab'),
  },
  {
    icon: <Computer />,
    path: '/dashboard/settings/devices',
    label: 'Desktop',
    match: (p: string) => p.startsWith('/dashboard/settings/devices'),
  },
  {
    icon: <Storage />,
    path: '/dashboard/database',
    label: 'БД',
    match: (p: string) => p.startsWith('/dashboard/database') || p.startsWith('/dashboard/baas'),
  },
  {
    icon: <SmartToy />,
    path: '/dashboard/business/ai',
    label: 'Помощник',
    match: (p: string) => p.startsWith('/dashboard/business/ai') || p.startsWith('/dashboard/developer/ai'),
  },
  {
    icon: <Settings />,
    path: '/dashboard/settings',
    label: 'Настройки',
    match: (p: string) => p.startsWith('/dashboard/settings'),
  },
] as const;

export function mobileNavForMode(_mode: CabinetMode) {
  return [
    { label: 'Стол', icon: <HomeWork />, path: '/dashboard' },
    { label: 'Обзор', icon: <Dashboard />, path: '/dashboard/overview' },
    { label: 'Метрики', icon: <QueryStats />, path: '/dashboard/ingest-lab/summary' },
    { label: 'Desktop', icon: <Computer />, path: '/dashboard/settings/devices' },
    { label: 'Ещё', icon: <Settings />, path: '/dashboard/settings' },
  ];
}

export type HubZone = {
  title: string;
  description: string;
  to: string;
  icon: React.ReactNode;
  badge?: string;
};

export const hubZones: HubZone[] = [
  {
    title: 'Обзор',
    description: 'Главные показатели и состояние сервисов.',
    to: '/dashboard/overview',
    icon: <Dashboard sx={{ fontSize: 28 }} />,
  },
  {
    title: 'Метрики',
    description: 'Сводка ingest и поток событий.',
    to: '/dashboard/ingest-lab/summary',
    icon: <QueryStats sx={{ fontSize: 28 }} />,
  },
  {
    title: 'Waypoint Desktop',
    description: 'Код привязки, устройства и синхронизация с ПК.',
    to: '/dashboard/settings/devices',
    icon: <Computer sx={{ fontSize: 28 }} />,
    badge: 'В приложении — проекты, Docker, терминал',
  },
  {
    title: 'Помощник',
    description: 'Вопросы по метрикам и операциям в облаке.',
    to: '/dashboard/business/ai',
    icon: <SmartToy sx={{ fontSize: 28 }} />,
  },
  {
    title: 'База данных',
    description: 'Таблицы, SQL-терминал, ER-схема, API.',
    to: '/dashboard/database',
    icon: <Storage sx={{ fontSize: 28 }} />,
  },
  {
    title: 'API и ключи',
    description: 'Подключение SDK и внешних систем.',
    to: '/dashboard/connect',
    icon: <Cable sx={{ fontSize: 28 }} />,
  },
];

export const infraHubZones: HubZone[] = [
  {
    title: 'Lynx Cloud',
    description: 'Облачные проекты и сборки (нужен сервер).',
    to: '/dashboard/lynx-cloud',
    icon: <Hub sx={{ fontSize: 28 }} />,
  },
  {
    title: 'Ingest Lab',
    description: 'Отправка событий, журнал, ключи.',
    to: '/dashboard/ingest-lab',
    icon: <QueryStats sx={{ fontSize: 28 }} />,
  },
];
