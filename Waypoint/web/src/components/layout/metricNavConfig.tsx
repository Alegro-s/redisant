import React from 'react';
import {
  Cable,
  Computer,
  HomeWork,
  QueryStats,
  Settings,
  AccountBalanceWallet,
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

/** Кабинет Metric: только облако + связка с Desktop. */
export const metricPrimarySections: MetricNavSection[] = [
  {
    title: 'Работа',
    items: [
      { text: 'Главная', icon: <HomeWork />, path: '/dashboard', secondary: 'С чего начать' },
      {
        text: 'Waypoint Desktop',
        icon: <Computer />,
        path: '/dashboard/settings/devices',
        secondary: 'Привязка компьютера',
      },
      {
        text: 'База данных',
        icon: <Storage />,
        path: '/dashboard/database',
        requiresServer: true,
        secondary: 'Таблицы и файлы',
      },
      {
        text: 'Метрики',
        icon: <QueryStats />,
        path: '/dashboard/ingest-lab/summary',
        secondary: 'События и отчёты',
      },
    ],
  },
  {
    title: 'Аккаунт',
    items: [
      { text: 'Ключи', icon: <Cable />, path: '/dashboard/connect', secondary: 'Для приложений' },
      { text: 'Настройки', icon: <Settings />, path: '/dashboard/settings' },
      { text: 'Тариф', icon: <AccountBalanceWallet />, path: '/dashboard/billing' },
    ],
  },
];

export const metricInfraSections: MetricNavSection[] = [];

export function navSectionsForMode(_mode: CabinetMode): MetricNavSection[] {
  return metricPrimarySections;
}

export const metricRailItems = [
  { icon: <HomeWork />, path: '/dashboard', label: 'Главная', match: (p: string) => p === '/dashboard' },
  {
    icon: <Computer />,
    path: '/dashboard/settings/devices',
    label: 'Desktop',
    match: (p: string) => p.startsWith('/dashboard/settings/devices'),
  },
  {
    icon: <Storage />,
    path: '/dashboard/database',
    label: 'База',
    match: (p: string) => p.startsWith('/dashboard/database'),
  },
  {
    icon: <QueryStats />,
    path: '/dashboard/ingest-lab/summary',
    label: 'Метрики',
    match: (p: string) => p.startsWith('/dashboard/ingest-lab'),
  },
  {
    icon: <Settings />,
    path: '/dashboard/settings',
    label: 'Ещё',
    match: (p: string) =>
      p.startsWith('/dashboard/settings') ||
      p.startsWith('/dashboard/connect') ||
      p.startsWith('/dashboard/billing'),
  },
] as const;

export function mobileNavForMode(_mode: CabinetMode) {
  return [
    { label: 'Главная', icon: <HomeWork />, path: '/dashboard' },
    { label: 'Desktop', icon: <Computer />, path: '/dashboard/settings/devices' },
    { label: 'База', icon: <Storage />, path: '/dashboard/database' },
    { label: 'Метрики', icon: <QueryStats />, path: '/dashboard/ingest-lab/summary' },
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
    title: 'Waypoint Desktop',
    description: 'Код для привязки и список ваших компьютеров.',
    to: '/dashboard/settings/devices',
    icon: <Computer sx={{ fontSize: 28 }} />,
    badge: 'Проекты и терминал — в программе на ПК',
  },
  {
    title: 'База данных',
    description: 'Таблицы, файлы и ключи для приложений.',
    to: '/dashboard/database',
    icon: <Storage sx={{ fontSize: 28 }} />,
  },
  {
    title: 'Метрики',
    description: 'Что происходит в ваших сервисах — в одной сводке.',
    to: '/dashboard/ingest-lab/summary',
    icon: <QueryStats sx={{ fontSize: 28 }} />,
  },
  {
    title: 'Ключи',
    description: 'Подключите сайт или приложение к облаку.',
    to: '/dashboard/connect',
    icon: <Cable sx={{ fontSize: 28 }} />,
  },
];

export const infraHubZones: HubZone[] = [];
