import React from 'react';
import { Link as RouterLink, Outlet } from 'react-router-dom';
import { Box, Typography, Button } from '@mui/material';
import { PageSubNav } from '../../components/layout/PageSubNav';

const subNavItems = [
  { label: '← Главная Waypoint', to: '/dashboard/waypoint' },
  { label: 'Запись в облако', to: '/dashboard/ingest-lab/send' },
  { label: 'Для бизнеса', to: '/dashboard/ingest-lab/business' },
  { label: 'Таблица метрик', to: '/dashboard/ingest-lab/metrics' },
  { label: 'Журнал логов', to: '/dashboard/ingest-lab/logs' },
  { label: 'Сводка → дашборд', to: '/dashboard/ingest-lab/summary' },
  { label: 'Симуляция и анализ', to: '/dashboard/ingest-lab/simulate' },
  { label: 'Ключи и расход', to: '/dashboard/ingest-lab/keys-usage' },
  { label: 'Платформа (события, диски)', to: '/dashboard/ingest-lab/developer-platform' },
];

export const IngestLabLayout: React.FC = () => {
  return (
    <Box sx={{ px: { xs: 2, sm: 3 }, py: { xs: 2, sm: 3 }, maxWidth: 1200, mx: 'auto' }}>
      <Box sx={{ display: 'flex', flexWrap: 'wrap', alignItems: 'center', gap: 1, mb: 2 }}>
        <Typography variant="h5" sx={{ fontWeight: 800, letterSpacing: '-0.02em', flex: '1 1 auto' }}>
          Ingest Lab
        </Typography>
        <Button component={RouterLink} to="/dashboard/waypoint/assistant" variant="outlined" size="small">
          AI-ассистент
        </Button>
      </Box>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        <strong>WaypointMetric</strong> — и для владельцев бизнеса (реклама, соцсети, репутация без кода), и для команд с
        облаками, серверами, тестами и ИИ. Раздел «Для бизнеса» — простыми словами; технический поток:{' '}
        <strong>Запись в облако</strong> из браузера (сессия) или <code>X-API-Key</code> с продакшена → дашборд и журнал логов. Ядро
        игры и релизы — в <RouterLink to="/dashboard/lynx-cloud/engine">Lynx Cloud → Ядро</RouterLink>.
      </Typography>
      <PageSubNav items={subNavItems} />
      <Outlet />
    </Box>
  );
};
