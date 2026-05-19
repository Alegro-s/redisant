import React from 'react';
import { Stack, Typography } from '@mui/material';
import { AiChatPanel } from '../../components/ai/AiChatPanel';

const STARTERS = [
  'Собери план дашборда для интернет-магазина.',
  'Какие метрики смотреть каждую неделю?',
  'Чеклист отчёта для руководства.',
  'Черновик письма клиенту о задержке доставки.',
];

export const BusinessAiPage: React.FC = () => {
  return (
    <Stack spacing={2}>
      <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.02em' }}>
        Помощник
      </Typography>
      <AiChatPanel
        persona="business"
        title="Вопросы по бизнесу и данным"
        subtitle="Спросите про отчёты, метрики или документы — ответит на русском, без технических терминов."
        starters={STARTERS}
        inputPlaceholder="Например: отчёт за месяц, метрики продаж, идея автоматизации…"
      />
    </Stack>
  );
};
