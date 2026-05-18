export const DATABASE_HUB_NAV = [
  { label: 'Обзор', to: '/dashboard/database', end: true },
  { label: 'ER-схема', to: '/dashboard/database/schema' },
  { label: 'Таблицы', to: '/dashboard/database/tables' },
  { label: 'SQL-терминал', to: '/dashboard/database/sql' },
  { label: 'API и ключи', to: '/dashboard/database/api' },
  { label: 'Файлы', to: '/dashboard/database/storage' },
] as const;
