import React from 'react';
import { Box, Paper, Typography } from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';


export const CloudCommercialPage: React.FC = () => {
  return (
    <Box sx={{ pt: 1, maxWidth: 720, mx: 'auto' }}>
      <Paper sx={{ p: 2, mb: 2 }}>
        <Typography variant="subtitle2" gutterBottom>
          Тарифы и внедрение
        </Typography>
        <Typography variant="body2" color="text.secondary" paragraph>
          Self-hosted: полный контроль, квоты WaypointMetric через переменные окружения, биллинг — ваш или{' '}
          <RouterLink to="/dashboard/billing">встроенный баланс</RouterLink> по мере развития. Managed: отдельная
          договорённость (выделенные воркеры сборки, приоритет очереди, SSO).
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Целевые ориентиры SLA (managed): 99.5% аптайм API проектов, ответ поддержки в рабочие часы — 4 ч для Pro, 1 ч для
          Enterprise (после запуска коммерческой линии).
        </Typography>
      </Paper>
      <Paper sx={{ p: 2 }}>
        <Typography variant="subtitle2" gutterBottom>
          Связка продуктов
        </Typography>
        <Typography variant="body2" color="text.secondary" component="div">
          <strong>WaypointMetric</strong> — метрики приложений и BaaS. <strong>Lynx Cloud</strong> — проекты и поставка
          движка. <strong>Lynx Hub</strong> — публичный вход и документация. Один аккаунт, разные области{' '}
          <code>X-Client-Realm</code>.
        </Typography>
      </Paper>
    </Box>
  );
};
