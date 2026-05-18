export type DesktopDocTopic =
  | 'start'
  | 'install'
  | 'requirements'
  | 'compare'
  | 'docker'
  | 'liza'
  | 'cloud'
  | 'security'
  | 'faq';

export type DesktopDocSection = {
  h: string;
  p: string;
};

export type DesktopDocChapter = {
  title: string;
  subtitle: string;
  sections: DesktopDocSection[];
};

export const DESKTOP_DOCS: Record<DesktopDocTopic, DesktopDocChapter> = {
  start: {
    title: 'Начало работы',
    subtitle: 'Что такое Waypoint Desktop и чем он отличается от облака',
    sections: [
      {
        h: 'Роль продукта',
        p: 'Waypoint Desktop — клиент серии Waypoint для ежедневной работы на ПК: Docker, терминал, планировщик и локальная Liza. Это не замена облачному Waypoint Metric (ingest, PostgreSQL, BaaS).',
      },
      {
        h: 'Когда использовать Desktop',
        p: 'Локальная разработка, скрипты, контейнеры у себя на машине. Когда нужны метрики, дашборды, командный workspace и облачная БД — открывайте Waypoint Metric.',
      },
      {
        h: 'Серия Waypoint',
        p: 'Desktop и Metric — два продукта одной линейки. У каждого свой сайт и свой сценарий; данные PostgreSQL в облаке не «переезжают» в Desktop автоматически.',
      },
    ],
  },
  install: {
    title: 'Установка',
    subtitle: 'Windows и первый запуск',
    sections: [
      {
        h: 'Требования',
        p: 'Windows 10/11 x64, Docker Desktop (для контейнерных сценариев), доступ в интернет для входа и опциональной связи с облаком.',
      },
      {
        h: 'Установщик',
        p: 'Скачайте сборку с главной страницы Desktop или из каталога Waypoint Club. После установки приложение создаёт рабочую папку и файл настроек в профиле пользователя.',
      },
      {
        h: 'Первый запуск',
        p: 'При первом старте выберите: только локальный режим или привязка к облачному workspace Metric (см. раздел «Связь с облаком»).',
      },
    ],
  },
  requirements: {
    title: 'Системные требования',
    subtitle: 'Windows, macOS и Linux',
    sections: [
      {
        h: 'Windows (рекомендуется)',
        p: 'Windows 10/11 x64, 8 ГБ RAM, 4 ГБ свободного диска, Docker Desktop для контейнеров, интернет для входа и облака.',
      },
      {
        h: 'macOS (beta)',
        p: 'macOS 12+, Apple Silicon или Intel. Docker Desktop обязателен для compose-сценариев. Сборка .dmg появится в канале beta.',
      },
      {
        h: 'Linux (beta)',
        p: 'Ubuntu 22.04+ / Fedora 39+. Docker Engine, polkit для доступа к сокету. AppImage в roadmap.',
      },
    ],
  },
  compare: {
    title: 'Desktop и Metric',
    subtitle: 'Сравнение продуктов серии Waypoint',
    sections: [
      {
        h: 'Кратко',
        p: 'Desktop — локальное рабочее место. Metric — облачная консоль: ingest, PostgreSQL, BaaS, команда.',
      },
    ],
  },
  docker: {
    title: 'Docker и терминал',
    subtitle: 'Локальное окружение разработчика',
    sections: [
      {
        h: 'Контейнеры',
        p: 'Desktop управляет проектами Docker на вашей машине: compose, логи, перезапуск сервисов. Облачный ingest Metric не обязателен для запуска контейнеров.',
      },
      {
        h: 'Терминал',
        p: 'Встроенная оболочка с историей команд и привязкой к каталогу проекта. Удобно для скриптов сборки и локальных утилит.',
      },
      {
        h: 'Планировщик',
        p: 'Задачи по расписанию на ПК (бэкапы, скрипты, health-check). Расписание хранится локально, не в облачной БД Metric.',
      },
    ],
  },
  liza: {
    title: 'Liza на ПК',
    subtitle: 'Локальный ассистент',
    sections: [
      {
        h: 'Отличие от облачной Liza',
        p: 'Liza в Desktop работает с вашим локальным окружением (файлы, Docker, терминал). Liza в Waypoint Metric — внутри облачного кабинета для метрик, логов и API.',
      },
      {
        h: 'Конфиденциальность',
        p: 'Запросы к локальным моделям или on-prem endpoint настраиваются в Desktop. Облачные ключи AI в Metric — отдельный контур.',
      },
    ],
  },
  cloud: {
    title: 'Связь с облаком Metric',
    subtitle: 'Как связать Desktop и Waypoint Metric',
    sections: [
      {
        h: 'Один аккаунт',
        p: 'И Desktop, и облачная консоль Metric используют общий auth-api (тот же email и пароль). Войдите в Desktop теми же учётными данными, что на metrika-waypoint.ru.',
      },
      {
        h: 'URL облака',
        p: 'В настройках Desktop укажите базовый URL облака: продакшен https://metrika-waypoint.ru, локально http://127.0.0.1:3002. API и auth проксируются с того же домена (/api, /auth).',
      },
      {
        h: 'API-ключ workspace',
        p: 'В кабинете Metric создайте ключ workspace (раздел BaaS / API). Скопируйте ключ в Desktop → «Облако» → «Ключ ingest». Desktop сможет отправлять выбранные метрики и логи в ingest Metric без ручного curl.',
      },
      {
        h: 'Что синхронизируется',
        p: 'По умолчанию синхронизируются только то, что вы явно включили: телеметрия ingest, статус задач, опционально ссылки на проекты. Локальная PostgreSQL, Docker volumes и файлы на диске в облако не копируются.',
      },
      {
        h: 'Открыть кабинет в браузере',
        p: 'Из Desktop кнопка «Открыть Metric» ведёт на облачный сайт с тем же аккаунтом (SSO через общий auth). Удобно для дашбордов, SQL и BaaS.',
      },
      {
        h: 'Схема для разработчиков',
        p: 'Desktop (Tauri) → auth-api :8090 (JWT) → при необходимости waypoint-api :8080 (ingest с X-API-Key). Переменные: WAYPOINT_CLOUD_URL, WAYPOINT_API_KEY, WAYPOINT_AUTH_URL — в config Desktop или .env рядом с приложением.',
      },
    ],
  },
  security: {
    title: 'Безопасность',
    subtitle: 'Данные на ПК и в облаке',
    sections: [
      {
        h: 'Локальные данные',
        p: 'Конфигурация и кэш Desktop хранятся в профиле пользователя Windows. Ключ API облака — в защищённом хранилище ОС.',
      },
      {
        h: 'Сеть',
        p: 'Связь с облаком только по HTTPS (в проде). Для локальной разработки допустим http://127.0.0.1 при включённом Docker-стеке.',
      },
    ],
  },
  faq: {
    title: 'FAQ',
    subtitle: 'Частые вопросы',
    sections: [
      {
        h: 'Нужен ли интернет?',
        p: 'Для Docker, терминала и локальной Liza — нет. Для входа и отправки метрик в Metric — да, в момент запроса.',
      },
      {
        h: 'Можно ли без Metric?',
        p: 'Да. Desktop полноценно работает локально. Облако — опциональное дополнение серии Waypoint.',
      },
      {
        h: 'Где полная документация Club?',
        p: 'Краткий обзор экосистемы остаётся на Waypoint Club; подробные разделы Desktop — на этом сайте в синей стилистике продукта.',
      },
    ],
  },
};

export const DESKTOP_COMPARE_ROWS: { feature: string; desktop: string; metric: string }[] = [
  { feature: 'Где работает', desktop: 'Ваш ПК', metric: 'Облако (браузер)' },
  { feature: 'Docker / терминал', desktop: 'Да, локально', metric: 'Нет (не IDE)' },
  { feature: 'Ingest метрик', desktop: 'Опционально → в облако', metric: 'Да, основной сценарий' },
  { feature: 'PostgreSQL / BaaS', desktop: 'Нет', metric: 'Да, workspace' },
  { feature: 'Liza', desktop: 'Локальный ассистент', metric: 'В кабинете для логов/API' },
  { feature: 'Офлайн', desktop: 'Да', metric: 'Нужен интернет' },
  { feature: 'Команда', desktop: 'Один ПК', metric: 'Workspace, роли, ключи' },
];

export const DESKTOP_DOC_NAV: { topic: DesktopDocTopic; label: string }[] = [
  { topic: 'start', label: 'Начало' },
  { topic: 'install', label: 'Установка' },
  { topic: 'requirements', label: 'Требования' },
  { topic: 'compare', label: 'Desktop vs Metric' },
  { topic: 'docker', label: 'Docker и терминал' },
  { topic: 'liza', label: 'Liza' },
  { topic: 'cloud', label: 'Связь с облаком' },
  { topic: 'security', label: 'Безопасность' },
  { topic: 'faq', label: 'FAQ' },
];
