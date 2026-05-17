import React from 'react';
import { Stack, Typography } from '@mui/material';
import { AiChatPanel } from '../../components/ai/AiChatPanel';

const STARTERS = [
  'Рефакторинг этого React-компонента: меньше ререндеров, типизация props.',
  'Сложность алгоритма для поиска по префиксу в большом словаре.',
  'Как безопасно параметризовать SQL в Rust (sqlx) против инъекций?',
  'Черновик OpenAPI-описания для POST /me/ai/chat.',
];

export const DeveloperAiPage: React.FC = () => {
  return (
    <Stack spacing={2}>
      <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.02em' }}>
        AI Copilot
      </Typography>
      <AiChatPanel
        persona="developer"
        title="Код и архитектура"
        subtitle="Модель по умолчанию — DeepSeek Coder (или задайте DEEPSEEK_MODEL_DEVELOPER на сервере). Не вставляйте секреты и ключи в чат."
        starters={STARTERS}
        inputPlaceholder="Код, ошибка стека, дизайн API, алгоритм…"
      />
    </Stack>
  );
};
