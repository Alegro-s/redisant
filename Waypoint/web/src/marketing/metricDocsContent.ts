export type MetricDocTopic = 'start' | 'ingest' | 'baas' | 'desktop' | 'billing' | 'roadmap';

export const METRIC_DOCS: Record<
  MetricDocTopic,
  { title: string; subtitle: string; sections: { h: string; p: string }[] }
> = {
  start: {
    title: 'Waypoint Metric',
    subtitle: 'Облачная консоль серии Waypoint',
    sections: [
      {
        h: 'Что входит',
        p: 'Ingest метрик и логов, PostgreSQL workspace, REST BaaS, object storage, Liza в кабинете, биллинг.',
      },
      {
        h: 'Вход',
        p: 'Регистрация на metrika-waypoint.ru → онбординг workspace → Ingest Lab.',
      },
    ],
  },
  ingest: {
    title: 'Ingest',
    subtitle: 'Приём метрик, логов и dev-событий',
    sections: [
      {
        h: 'API-ключ',
        p: 'Заголовок X-API-Key или POST /me/ingest из кабинета с сессией JWT.',
      },
      {
        h: 'Шаблон Desktop',
        p: 'В Ingest Lab → «Шаблон Desktop» — payload с host=desktop и метриками cpu_percent, docker_running.',
      },
      {
        h: 'Лимиты',
        p: 'Rate limit per API key: 50 000 событий / 60 с (Redis). Отдельные ключи scope=desktop.',
      },
    ],
  },
  baas: {
    title: 'BaaS и PostgreSQL',
    subtitle: 'Данные приложения в workspace',
    sections: [
      {
        h: 'SQL и REST',
        p: 'Консоль BaaS: таблицы, REST по /me/baas/rest/{table}, realtime WebSocket.',
      },
    ],
  },
  desktop: {
    title: 'Подключение Desktop',
    subtitle: 'Связь с Waypoint Desktop',
    sections: [
      {
        h: 'Привязка',
        p: 'Кабинет → Настройки → Подключённые устройства → код WD-XXXXXXXX → ввести в Desktop.',
      },
      {
        h: 'Хосты',
        p: 'Раздел «Desktop hosts» показывает машины с last_seen и ОС.',
      },
    ],
  },
  billing: {
    title: 'Тарифы',
    subtitle: 'Биллинг workspace',
    sections: [
      {
        h: 'Оплата',
        p: 'Раздел Billing в кабинете: квоты ingest, AI, storage. YooKassa webhook на сервере.',
      },
    ],
  },
  roadmap: {
    title: 'Roadmap платформы',
    subtitle: 'План развития Waypoint Metric',
    sections: [
      {
        h: 'Инфраструктура',
        p: 'Managed K8s, CDN, backup, балансировщики, DNS/SSL, Terraform provider — в разработке.',
      },
      {
        h: 'Продукт',
        p: 'Конструктор дашбордов, центр уведомлений, mobile SDK, SLA monitoring, шаблоны отчётов.',
      },
    ],
  },
};

export const METRIC_DOC_NAV: { topic: MetricDocTopic; label: string }[] = [
  { topic: 'start', label: 'Начало' },
  { topic: 'ingest', label: 'Ingest' },
  { topic: 'baas', label: 'BaaS' },
  { topic: 'desktop', label: 'Desktop' },
  { topic: 'billing', label: 'Тарифы' },
  { topic: 'roadmap', label: 'Roadmap' },
];
