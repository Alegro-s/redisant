export type LegalSection = { title: string; paragraphs: string[] };

export const lynxPrivacySections: LegalSection[] = [
  {
    title: '1. Общие положения',
    paragraphs: [
      'Политика описывает обработку данных в Lynx Cloud, Lynx Hub и Lynx Launcher (экосистема Lynx).',
      'По вопросам данных обращайтесь в поддержку через Lynx Hub.',
    ],
  },
  {
    title: '2. Какие данные обрабатываются',
    paragraphs: [
      'Email, никнейм, настройки аккаунта, технические журналы и контент ваших проектов — в объёме, нужном для работы сервиса.',
    ],
  },
  {
    title: '3. Ваши права',
    paragraphs: ['Запрос на доступ, исправление или удаление данных — через поддержку Lynx.'],
  },
];

export const lynxTermsSections: LegalSection[] = [
  {
    title: '1. Условия',
    paragraphs: [
      'Используя Lynx Cloud, вы принимаете эти условия. Metric и Roza AI — отдельные продукты.',
    ],
  },
  {
    title: '2. Аккаунт',
    paragraphs: [
      'Новый аккаунт Lynx создаётся в Lynx Launcher. В Cloud и Hub — вход для существующих пользователей.',
    ],
  },
  {
    title: '3. Права на ПО',
    paragraphs: [
      'ПО Lynx и бренд защищены правообладателем. Контент проектов остаётся вашим. Копирование и изменение движка без разрешения запрещены.',
    ],
  },
];
