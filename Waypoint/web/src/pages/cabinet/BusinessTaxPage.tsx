import React from 'react';
import { Stack, Typography, Checkbox, FormControlLabel, Card, CardContent, useTheme } from '@mui/material';
import { WM_CLOUD } from '../../components/layout/cloudShell';
import { FeatureGate } from '../../components/common/FeatureGate';

const CHECKLIST = [
  'Сверка выручки с платёжным агрегатором',
  'Учёт возвратов и корректировок',
  'Разнесение расходов по статьям',
  'Сохранение первички (PDF) в BaaS Storage',
];

export const BusinessTaxPage: React.FC = () => {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';

  return (
    <Stack spacing={2.5}>
      <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.02em' }}>
        Налоги и отчётность
      </Typography>
      <Typography variant="body1" color="text.secondary" sx={{ maxWidth: 800, lineHeight: 1.65 }}>
        Инструмент не заменяет бухгалтера. Чеклист и напоминания помогают собрать данные; выгрузки для сдачи — зона Pro.
      </Typography>

      <Card
        sx={{
          borderRadius: 3,
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
        }}
      >
        <CardContent>
          <Typography variant="subtitle1" fontWeight={700} sx={{ mb: 1 }}>
            Чеклист периода
          </Typography>
          <Stack>
            {CHECKLIST.map((label) => (
              <FormControlLabel key={label} control={<Checkbox size="small" />} label={label} />
            ))}
          </Stack>
        </CardContent>
      </Card>

      <FeatureGate
        feature="tax_exports"
        title="Выгрузки для отчётности"
        description="CSV / Excel по периоду: выручка, НДС-черновик, расходы — из ваших таблиц BaaS."
      >
        <Typography variant="body2" color="text.secondary">
          На Pro доступны сценарии экспорта; подключите представления SQL и задайте расписание в заданиях сервера.
        </Typography>
      </FeatureGate>
    </Stack>
  );
};
