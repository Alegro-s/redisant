import React from 'react';
import { Box, Card, CardContent, Grid, Typography } from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';
import { TrendingUp, Campaign, Forum, Analytics, Web, Brush, CloudQueue } from '@mui/icons-material';


const cards = [
  {
    title: 'Реклама и конверсии',
    icon: <TrendingUp color="primary" />,
    text: 'Считайте заявки, покупки и стоимость лида. События канала performance в ingest — готовая основа для отчётов и дашбордов.',
    channel: 'performance',
  },
  {
    title: 'Бренд и охваты',
    icon: <Campaign color="primary" />,
    text: 'Фиксируйте охват и узнаваемость (brandformance): единый поток данных для маркетинга и руководства.',
    channel: 'brandformance',
  },
  {
    title: 'Соцсети и диалоги',
    icon: <Forum color="primary" />,
    text: 'Вовлечённость, отклики на посты, сводки по SMM — без ручных таблиц.',
    channel: 'smm',
  },
  {
    title: 'Репутация',
    icon: <Analytics color="primary" />,
    text: 'Отзывы и сигналы настроения (reputation) — видно в одном месте, можно подключить уведомления.',
    channel: 'reputation',
  },
  {
    title: 'Сайт и стабильность',
    icon: <Web color="primary" />,
    text: 'События деплоя, ошибки, скорость ответа (web_dev + логи) — контроль «жив ли сайт».',
    channel: 'web_dev',
  },
  {
    title: 'Материалы и дизайн',
    icon: <Brush color="primary" />,
    text: 'Варианты креативов и продакшн-события (design) — для согласований и A/B.',
    channel: 'design',
  },
  {
    title: 'Файлы и облако',
    icon: <CloudQueue color="primary" />,
    text: 'Реестр подключений к S3 и «сетевым дискам» (storage) — как у облачного хостинга: endpoint, протокол, префикс.',
    channel: 'storage',
  },
];

export const IngestLabBusinessPage: React.FC = () => {
  return (
    <Box>
      <Typography variant="h5" gutterBottom sx={{ fontWeight: 700 }}>
        WaypointMetric для бизнеса
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 3, maxWidth: 720 }}>
        Не нужно быть разработчиком: мы собираем цифры о рекламе, соцсетях, репутации и сайте в одну среду. Подрядчик или
        IT-отдел подключает поток данных; вы смотрите сводки и ключи в{' '}
        <RouterLink to="/dashboard/ingest-lab/keys-usage">разделе ключей</RouterLink> и на дашборде. Техническая глубина — в
        разделе «Платформа» и в BaaS.
      </Typography>
      <Grid container spacing={2}>
        {cards.map((c) => (
          <Grid item xs={12} sm={6} md={4} key={c.channel}>
            <Card variant="outlined" sx={{ height: '100%', borderRadius: 2 }}>
              <CardContent>
                <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
                  {c.icon}
                  <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                    {c.title}
                  </Typography>
                </Box>
                <Typography variant="body2" color="text.secondary">
                  {c.text}
                </Typography>
                <Typography variant="caption" color="primary" sx={{ mt: 1, display: 'block' }}>
                  Канал ingest: <code>{c.channel}</code>
                </Typography>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
      <Typography variant="body2" sx={{ mt: 3 }}>
        Полный каталог услуг и акций:{' '}
        <RouterLink to="/dashboard/waypoint/business">Waypoint → Для бизнеса</RouterLink>
        {' · '}
        <RouterLink to="/dashboard/waypoint/developers">Для разработчиков</RouterLink>
        {' · '}
        <RouterLink to="/dashboard/ingest-lab/developer-platform">события и диски (ingest)</RouterLink>
        {' · '}
        <RouterLink to="/dashboard/ingest-lab/simulate">симуляция батча</RouterLink>
        {' · '}
        <RouterLink to="/dashboard/baas">база и хранилище (BaaS)</RouterLink>
      </Typography>
    </Box>
  );
};
