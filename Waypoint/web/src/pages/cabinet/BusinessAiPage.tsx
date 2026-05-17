import React from 'react';
import { Stack, Typography } from '@mui/material';
import { AiChatPanel } from '../../components/ai/AiChatPanel';

const STARTERS = [
  'Собери план дашборда для e-commerce на основе каналов performance и analytics.',
  'Как оформить ingest-события для сквозной аналитики рекламы?',
  'Чеклист автоматизации еженедельного отчёта для руководства.',
  'Черновик письма клиенту о задержке доставки (нейтральный тон).',
];

export const BusinessAiPage: React.FC = () => {
  return (
    <Stack spacing={2}>
      <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.02em' }}>
        AI для бизнеса
      </Typography>
      <AiChatPanel
        persona="business"
        title="Аналитика и операции"
        subtitle="Модель по умолчанию — диалоговая (DeepSeek Chat). Данные аккаунта не передаются автоматически — уточняйте контекст в сообщении."
        starters={STARTERS}
        inputPlaceholder="Метрики, логистика, отчёт, документ, идея автоматизации…"
      />
    </Stack>
  );
};
