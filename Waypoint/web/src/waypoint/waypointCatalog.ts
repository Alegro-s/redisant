

export type ServiceDelivery = 'console' | 'partial' | 'manager';

export interface WaypointServiceCard {
  title: string;
  description: string;
  badge?: 'NEW' | 'SOON';
  delivery: ServiceDelivery;
  
  href?: string;
  
  ingestChannel?: string;
}

export interface WaypointServiceSection {
  id: string;
  label: string;
  cards: WaypointServiceCard[];
}


export const WAYPOINT_PROMOTIONS: {
  title: string;
  detail: string;
  tag: string;
}[] = [
  {
    tag: 'Digital',
    title: 'Digital с прогнозом',
    detail: 'Комплекс с прогнозом лидов — обсудите SLA и сквозную аналитику с командой.',
  },
  {
    tag: 'ORM',
    title: 'ORM-обслуживание',
    detail: 'Скидка 10% на абонентку в первые 2 месяца (актуальность уточняйте у менеджера).',
  },
  {
    tag: 'Performance',
    title: 'Performance',
    detail: 'Digital-комплекс под ключ: до 25% на первый месяц при быстром старте.',
  },
  {
    tag: 'SMM',
    title: 'SMM-обслуживание',
    detail: 'До 15% на абонентку в первые 2 месяца.',
  },
  {
    tag: 'SEO',
    title: 'SEO + Medkit',
    detail: 'До 25% при быстром запуске медицинского пакета и поискового продвижения.',
  },
  {
    tag: 'Аналитика',
    title: 'Сквозная аналитика',
    detail: 'До 20% на внедрение при быстром запуске интеграций.',
  },
  {
    tag: 'Реклама',
    title: 'Таргет и контекст',
    detail: 'До 25% при быстром запуске кампаний и настройке событий в WaypointMetric.',
  },
];

export const BUSINESS_SECTIONS: WaypointServiceSection[] = [
  {
    id: 'performance',
    label: 'Performance',
    cards: [
      {
        title: 'Performance-маркетинг',
        description: 'Стратегия привлечения целевых лидов; события и конверсии — в ingest (канал performance).',
        delivery: 'partial',
        href: '/dashboard/ingest-lab/developer-platform',
        ingestChannel: 'performance',
      },
      {
        title: 'CJM — путь клиента',
        description: 'Исследование воронки; фиксация шагов в analytics + метрики в WaypointMetric.',
        delivery: 'manager',
        ingestChannel: 'analytics',
      },
      {
        title: 'Таргетированная реклама',
        description: 'VK, MyTarget и др.; UTM и события сводим в единый поток данных.',
        delivery: 'manager',
        ingestChannel: 'performance',
      },
      {
        title: 'Контекстная реклама',
        description: 'Быстрый вывод аудитории; связка с метриками и AI-отчётами в консоли.',
        delivery: 'manager',
        ingestChannel: 'performance',
      },
      {
        title: 'Digital-комплекс',
        description: 'SEO + контекст, единая команда и прогноз лидов; дашборды — через Waypoint + AI-ассистент.',
        delivery: 'manager',
      },
      {
        title: 'Медийная реклама',
        description: 'Охваты и узнаваемость бренда; отчёты по охватам в analytics / brandformance.',
        delivery: 'manager',
        ingestChannel: 'brandformance',
      },
      {
        title: 'Продвижение с оплатой за лиды',
        description: 'Аналитика лидов и рост конверсий; учёт в метриках и логах.',
        delivery: 'manager',
        ingestChannel: 'performance',
      },
      {
        title: 'RTB',
        description: 'Расширение охвата и конверсий programmatic; интеграции данных — по запросу.',
        delivery: 'manager',
      },
    ],
  },
  {
    id: 'search',
    label: 'Поисковое продвижение',
    cards: [
      {
        title: 'SEO: оптимизация и продвижение',
        description: 'Видимость в Яндекс и Google; технические события — web_dev + логи.',
        delivery: 'manager',
        ingestChannel: 'web_dev',
      },
      {
        title: 'AI SEO',
        description: 'Ускорение роста в поиске с опорой на ИИ; отчёты и гипотезы — через AI-ассистента.',
        delivery: 'manager',
      },
      {
        title: 'Продвижение по позициям',
        description: 'Индивидуальная стратегия вывода в ТОП.',
        delivery: 'manager',
      },
      {
        title: 'Продвижение по трафику',
        description: 'Контент и объём трафика; метрики посещений в WaypointMetric.',
        delivery: 'manager',
        ingestChannel: 'analytics',
      },
      {
        title: 'SEO-аудит',
        description: 'Аналитика процессов сайта для роста в выдаче.',
        delivery: 'manager',
      },
    ],
  },
  {
    id: 'reputation',
    label: 'Управление имиджем',
    cards: [
      {
        title: 'ORM',
        description: 'Репутационный фон бренда; сигналы — канал reputation в ingest.',
        delivery: 'partial',
        href: '/dashboard/ingest-lab/developer-platform',
        ingestChannel: 'reputation',
      },
      {
        title: 'SERM',
        description: 'Поисковая репутация; мониторинг и отчёты.',
        delivery: 'manager',
        ingestChannel: 'reputation',
      },
      {
        title: 'Репутация на маркетплейсах и в ритейле',
        description: 'Рейтинги и отзывы; события продаж и отзывов в analytics.',
        delivery: 'manager',
        ingestChannel: 'reputation',
      },
      {
        title: 'Продвижение на маркетплейсах',
        description: 'Вход, стоимость, стратегия; учёт KPI в дашбордах.',
        delivery: 'manager',
      },
    ],
  },
  {
    id: 'analytics',
    label: 'Аналитика и аудиты',
    cards: [
      {
        title: 'Комплексная веб-аналитика',
        description: 'Рост прибыли от маркетинга; сводки в консоли и AI.',
        delivery: 'partial',
        href: '/dashboard/ingest-lab/summary',
        ingestChannel: 'analytics',
      },
      {
        title: 'BI-аналитика',
        description: 'Прозрачные отчёты; экспорт и SQL — BaaS / внешние BI.',
        delivery: 'partial',
        href: '/dashboard/baas/sql',
      },
      {
        title: 'Сквозная аналитика',
        description: 'От клика до конверсии в одном окне; события WaypointMetric.',
        delivery: 'partial',
        href: '/dashboard/ingest-lab/keys-usage',
        ingestChannel: 'analytics',
      },
      {
        title: 'Сквозная аналитика для клиник',
        description: 'Медицинский контур данных и доходность; чувствительные данные — сегментация и доступы.',
        delivery: 'manager',
      },
      {
        title: 'CustDev и глубинные интервью',
        description: 'Понимание спроса без лишних затрат на маркетинг и разработку.',
        delivery: 'manager',
      },
      {
        title: 'Юзабилити-аудит',
        description: 'Рост конверсии за счёт UX; гипотезы в AI-ассистенте.',
        delivery: 'manager',
      },
      {
        title: 'Аудит системы продаж',
        description: 'Точки роста и процессы продаж.',
        delivery: 'manager',
      },
      {
        title: 'Настройка Google Analytics 4',
        description: 'Качественная веб-аналитика, cookie-less тренды; события в ingest.',
        delivery: 'manager',
      },
      {
        title: 'Food Scan',
        description: 'Исследования FMCG на полках и в digital.',
        delivery: 'manager',
      },
      {
        title: 'UX-исследования с респондентами',
        description: 'Качественные и количественные исследования UX.',
        delivery: 'manager',
      },
    ],
  },
  {
    id: 'vertical',
    label: 'Отраслевые решения',
    cards: [
      {
        title: 'FMCG',
        description: 'Полка и корзина; измеримые кампании.',
        delivery: 'manager',
      },
      {
        title: 'Автомобильные сайты',
        description: 'Специализированное продвижение авто-тематики.',
        delivery: 'manager',
      },
      {
        title: 'Medkit',
        description: 'Digital для клиник и фармы.',
        delivery: 'manager',
      },
      {
        title: 'Интернет-магазины',
        description: 'Под ключ: трафик, конверсия, аналитика.',
        delivery: 'manager',
      },
    ],
  },
  {
    id: 'sites',
    label: 'Создание и доработка сайтов',
    cards: [
      {
        title: 'Редизайн сайта',
        description: 'Конверсия и обновление UX/UI.',
        delivery: 'manager',
        ingestChannel: 'web_dev',
      },
      {
        title: 'Сайты под ключ',
        description: 'Сильный digital-актив для конкуренции.',
        delivery: 'manager',
      },
      {
        title: 'Адаптивная (мобильная) версия',
        description: 'Быстрее привлекать мобильных клиентов.',
        delivery: 'manager',
      },
      {
        title: 'Разработка web-сервисов',
        description: 'Сложные сервисы и SEO-старт.',
        delivery: 'manager',
      },
    ],
  },
  {
    id: 'design_smm',
    label: 'Дизайн и продакшн',
    cards: [
      {
        title: 'Дизайн для бизнеса',
        description: 'Креативы с высоким approve; варианты в канале design.',
        delivery: 'manager',
        ingestChannel: 'design',
      },
      {
        title: 'Экспресс-дизайн',
        description: 'Быстрые макеты под задачи.',
        delivery: 'manager',
        ingestChannel: 'design',
      },
      {
        title: 'Фотоконтент',
        description: 'Контент для бизнеса и соцсетей.',
        delivery: 'manager',
      },
      {
        title: 'SMM',
        description: 'Бренд и коммуникации в соцсетях; канал smm.',
        delivery: 'manager',
        ingestChannel: 'smm',
      },
      {
        title: 'ВКонтакте: группа под ключ',
        description: 'Стратегия, визуал, контент, вовлечение.',
        delivery: 'manager',
        ingestChannel: 'smm',
      },
      {
        title: 'Реклама в Telegram Ads',
        description: 'Лиды из мессенджера с первых недель.',
        delivery: 'manager',
      },
      {
        title: 'Ведение Telegram-канала',
        description: 'Охват и продажи в Telegram.',
        delivery: 'manager',
        ingestChannel: 'smm',
      },
      {
        title: 'Информационные охватные стратегии',
        description: 'Рост охвата x2+ на площадках.',
        delivery: 'manager',
      },
      {
        title: 'Яндекс.Дзен',
        description: 'Контент для продвижения компании и продуктов.',
        delivery: 'manager',
      },
    ],
  },
];

export const DEVELOPER_SECTIONS: WaypointServiceSection[] = [
  {
    id: 'core',
    label: 'Проекты и платформа',
    cards: [
      {
        title: 'Проекты',
        description: 'Игровые и студийные проекты в общем контуре.',
        delivery: 'console',
        href: '/dashboard/projects',
      },
      {
        title: 'Общий проект / workspace',
        description: 'Git и окружение разработчика.',
        delivery: 'console',
        href: '/dashboard/git',
      },
      {
        title: 'Создать проект',
        description: 'Новый проект в платформе.',
        delivery: 'console',
        href: '/dashboard/projects',
      },
      {
        title: 'Lynx Cloud',
        description: 'Облачные dev-проекты, ядро Lynx, сборки.',
        delivery: 'console',
        href: '/dashboard/lynx-cloud',
      },
      {
        title: 'AI-агенты',
        description: 'Ассистент аналитики и автоматизации в WaypointMetric.',
        delivery: 'console',
        href: '/dashboard/waypoint/assistant',
      },
      {
        title: 'App Platform',
        description: 'API, модули тестирования, артефакты.',
        delivery: 'partial',
        href: '/dashboard/api',
      },
    ],
  },
  {
    id: 'infra',
    label: 'Инфраструктура',
    cards: [
      {
        title: 'Облачные серверы',
        description: 'Аренда инстансов через консоль (Server Rent).',
        delivery: 'partial',
        href: '/dashboard/instances',
      },
      {
        title: 'Выделенные серверы',
        description: 'Расширенный хостинг — заявка и биллинг.',
        delivery: 'manager',
        href: '/dashboard/billing',
      },
      {
        title: 'Облако 5 ГГц',
        description: 'Высокочастотные CPU — в roadmap.',
        badge: 'NEW',
        delivery: 'partial',
      },
      {
        title: 'Облако VMware',
        description: 'Корпоративная виртуализация.',
        badge: 'SOON',
        delivery: 'partial',
      },
      {
        title: 'Гибкие бэкапы',
        description: 'Политики снапшотов и off-site.',
        badge: 'SOON',
        delivery: 'partial',
      },
      {
        title: 'Kubernetes',
        description: 'Оркестрация контейнеров.',
        delivery: 'partial',
      },
      {
        title: 'Балансировщики',
        description: 'L4/L7 балансировка.',
        delivery: 'partial',
      },
      {
        title: 'Сети',
        description: 'VPC, приватные сети.',
        delivery: 'partial',
      },
      {
        title: 'CDN',
        description: 'Доставка статики по edge.',
        badge: 'SOON',
        delivery: 'partial',
      },
    ],
  },
  {
    id: 'data',
    label: 'Данные и наблюдаемость',
    cards: [
      {
        title: 'Мониторинг',
        description: 'Метрики, логи, алерты WaypointMetric.',
        badge: 'SOON',
        delivery: 'partial',
        href: '/dashboard/ingest-lab',
      },
      {
        title: 'Базы данных',
        description: 'PostgreSQL и SQL-консоль.',
        delivery: 'console',
        href: '/dashboard/database',
      },
      {
        title: 'BaaS — SQL / REST / realtime',
        description: 'База и API для приложений.',
        delivery: 'console',
        href: '/dashboard/baas',
      },
      {
        title: 'Хранилище S3',
        description: 'Объектное хранилище (buckets).',
        delivery: 'console',
        href: '/dashboard/baas/storage',
      },
      {
        title: 'Сетевые диски',
        description: 'Реестр endpoint S3/WebDAV/NFS и события storage.',
        delivery: 'partial',
        href: '/dashboard/ingest-lab/developer-platform',
      },
    ],
  },
  {
    id: 'edge',
    label: 'Edge и доступ',
    cards: [
      {
        title: 'Домены и SSL',
        description: 'Управление DNS и сертификатами — вне консоли или интеграция.',
        delivery: 'manager',
      },
      {
        title: 'Почта',
        description: 'Корпоративная почта — внешний провайдер.',
        delivery: 'manager',
      },
      {
        title: 'Баланс и платежи',
        description: 'Биллинг и пополнение.',
        delivery: 'console',
        href: '/dashboard/billing',
      },
      {
        title: 'API и Terraform',
        description: 'HTTP API документирован; IaC — roadmap.',
        delivery: 'partial',
        href: '/dashboard/api',
      },
      {
        title: 'Уведомления',
        description: 'Webhooks, VK, алерты по логам.',
        delivery: 'partial',
        href: '/dashboard/vk-bot',
      },
      {
        title: 'Документация',
        description: 'Встроенные docs консоли.',
        delivery: 'console',
        href: '/dashboard/docs',
      },
      {
        title: 'Android-приложение',
        description: 'Клиент Lynx / лаунчер.',
        delivery: 'partial',
      },
    ],
  },
];


export const WAYPOINT_CAPABILITY_GAPS: string[] = [
  'Выделенный managed Kubernetes с UI и kubeconfig в один клик.',
  'Managed CDN с конфигом origin и инвалидацией кэша из консоли.',
  'Политики резервного копирования БД/объектов с расписанием и restore self-service.',
  'L4/L7 балансировщики как сервис с health-check и сертификатами.',
  'Полноценный DNS/SSL модуль (заявки сейчас вне продукта).',
  'Корпоративная почта как продуктовая строка.',
  'Terraform provider под все ресурсы платформы.',
  'Центр уведомлений (email/push/telegram) с политиками подписки.',
  'Mobile SDK и пуши для Android/iOS под бренд Lynx.',
  'Маркетплейс «услуг с менеджером» с заказом из консоли и статусом в ЛК.',
  'Встроенный конструктор дашбордов (drag-drop) поверх ingest/BaaS.',
  'Автогенерация PDF/Doc отчётов из шаблонов и данных BaaS.',
  'Сегментация данных и row-level security для мультиарендности бизнес-кабинетов.',
];
