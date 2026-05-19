export const DATABASE_HUB_NAV = [
  { label: 'Обзор', to: '/dashboard/database', end: true },
  { label: 'Схема', to: '/dashboard/database/schema' },
  { label: 'Таблицы', to: '/dashboard/database/tables' },
  { label: 'Запросы', to: '/dashboard/database/sql' },
  { label: 'Ключи', to: '/dashboard/database/api' },
  { label: 'Файлы', to: '/dashboard/database/storage' },
] as const;
