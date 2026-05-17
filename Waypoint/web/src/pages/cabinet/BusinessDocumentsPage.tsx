import React from 'react';
import { Button, Stack, Typography, Card, CardContent, alpha, useTheme } from '@mui/material';
import { OpenInNew } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { WM_CLOUD } from '../../components/layout/cloudShell';
import { FeatureGate } from '../../components/common/FeatureGate';

export const BusinessDocumentsPage: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const isDark = theme.palette.mode === 'dark';

  return (
    <Stack spacing={2.5}>
      <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.02em' }}>
        Документы и шаблоны
      </Typography>
      <Typography variant="body1" color="text.secondary" sx={{ maxWidth: 800, lineHeight: 1.65 }}>
        Генерация и хранение черновиков: накладные, акты, заявки в службы доставки. Данные храните в BaaS / PostgreSQL;
        здесь — маршруты и идеи сценариев. Расширенный пакет шаблонов и пакетная выгрузка — на Pro.
      </Typography>

      <FeatureGate
        feature="documents_templates_pack"
        title="Пакет шаблонов Pro"
        description="Готовые формы под СДЭК, Почту России и др., пакетный PDF и подстановка полей из BaaS."
      >
        <Card
          sx={{
            borderRadius: 3,
            border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
            bgcolor: isDark ? alpha(WM_CLOUD.paperElevated, 0.35) : alpha(theme.palette.success.main, 0.04),
          }}
        >
          <CardContent>
            <Typography variant="subtitle1" fontWeight={700}>
              Шаблоны Pro активны
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
              Подключите таблицы контрагентов и отгрузок в BaaS, затем используйте AI в разделе «AI для бизнеса» для
              черновиков текстов под конкретную службу.
            </Typography>
          </CardContent>
        </Card>
      </FeatureGate>

      <Stack direction="row" flexWrap="wrap" gap={1}>
        <Button variant="contained" onClick={() => navigate('/dashboard/baas/sql')}>
          Открыть BaaS SQL
        </Button>
        <Button variant="outlined" endIcon={<OpenInNew />} onClick={() => navigate('/dashboard/business/ai')}>
          AI: черновик документа
        </Button>
      </Stack>
    </Stack>
  );
};
