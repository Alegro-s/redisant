import { desktopDocsUrl } from './links';

export type ClubDocProduct =
  | 'metric'
  | 'desktop'
  | 'lynx'
  | 'roza-ai'
  | 'roza-os'
  | 'tspu';

export const CLUB_DOCS: Record<
  ClubDocProduct,
  { title: string; subtitle: string; sections: { h: string; p: string }[] }
> = {
  metric: {
    title: 'Waypoint Metric',
    subtitle: 'Облачная консоль: метрики, ingest, PostgreSQL, BaaS',
    sections: [
      {
        h: 'Что это',
        p: 'Веб-платформа серии Waypoint после входа: ingest метрик и логов, дашборды, алерты, PostgreSQL, REST BaaS и object storage в своём workspace.',
      },
      {
        h: 'База данных',
        p: 'У workspace свой PostgreSQL и API-ключи. Разделы BaaS в кабинете: SQL, REST, хранилище. Лимиты по тарифу Basic / Business.',
      },
      {
        h: 'Вход',
        p: 'Регистрация на metrika-waypoint.ru → онбординг workspace → Ingest Lab и кабинет. Liza — ассистент внутри Metric для логов и API.',
      },
    ],
  },
  desktop: {
    title: 'Waypoint Desktop',
    subtitle: 'Локальное приложение на вашем ПК',
    sections: [
      {
        h: 'Что это',
        p: 'Отдельный клиент: Docker, терминал, планировщик, Liza на рабочем столе. Не заменяет облачный ingest и BaaS Waypoint Metric.',
      },
      {
        h: 'Полная документация',
        p: `Подробные разделы — на Metric: ${desktopDocsUrl()}`,
      },
      {
        h: 'Отличие от Metric',
        p: 'Metric — облако и командная эксплуатация. Desktop — ежедневная разработка «у себя»; связь с облаком опциональна (см. раздел «Связь с облаком» на сайте Desktop).',
      },
    ],
  },
  lynx: {
    title: 'Lynx',
    subtitle: '2D-игровой движок, Hub и Cloud',
    sections: [
      {
        h: 'Продукты',
        p: 'Lynx Hub (lynx-hub.ru) — скачивание Launcher. Lynx Cloud (lynx-cloud.ru/cabinet) — свой кабинет Lynx, не Waypoint Metric.',
      },
      {
        h: 'Документация',
        p: 'Руководство разработчика и релизы — на сайте Lynx Hub (/docs). Club даёт обзор; детали — в Hub и Cloud.',
      },
      {
        h: 'База данных',
        p: 'Облачные данные проектов и сборок — в Lynx Cloud, не в Waypoint Metric. У каждого продукта свой контур данных.',
      },
    ],
  },
  'roza-ai': {
    title: 'Roza AI',
    subtitle: 'Подсерия Roza в линейке Waypoint',
    sections: [
      {
        h: 'Что это',
        p: 'Roza AI — веб-чат, API и приложение для Windows в подсерии Roza. Документы, безопасность ПК и обучение. Сайт: waypointclub.ru/roza.',
      },
      {
        h: 'Скачивание',
        p: 'Приложение для Windows — на странице Roza AI. Требуется .NET 8 и локальный сервер Roza.',
      },
      {
        h: 'Личный кабинет',
        p: 'Подписка и ключи API — в кабинете Roza на waypointclub.ru/roza/account (не Metric).',
      },
    ],
  },
  'roza-os': {
    title: 'Roza OS',
    subtitle: 'Дистрибутив для разработки',
    sections: [
      {
        h: 'Что это',
        p: 'Операционная система / дистрибутив с встроенным ассистентом. Развивается отдельно от Roza AI и Waypoint.',
      },
      {
        h: 'Статус',
        p: 'Публичная загрузка — после стабилизации ядра. Анонсы на roza.ru/os.',
      },
      {
        h: 'Данные',
        p: 'Локальная установка; облачный контур OS — по мере запуска сервисов Roza.',
      },
    ],
  },
  tspu: {
    title: 'ТГПУ Профиль',
    subtitle: 'Мобильное приложение для студентов ТГПУ',
    sections: [
      {
        h: 'Что это',
        p: 'Расписание, оценки, Moodle, кампус и карта лояльности для Тульского педагогического университета.',
      },
      {
        h: 'Сайт',
        p: 'Презентация приложения — на waypointclub.ru/tspu. RuStore — по мере публикации.',
      },
      {
        h: 'Данные',
        p: 'Синхронизация с 1С и Moodle вуза; персональные данные студента — в контуре вуза и приложения.',
      },
    ],
  },
};
