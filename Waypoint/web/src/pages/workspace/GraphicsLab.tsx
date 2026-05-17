import React from 'react';
import { Box, Paper, Typography } from '@mui/material';

export const GraphicsLab: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
        Графические функции
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2.5 }}>
        Визуальные сценарии: графики, диаграммы и rendering-пайплайн.
      </Typography>
      <Paper sx={{ p: 3, borderRadius: 3 }}>
        <Typography variant="body2" color="text.secondary">
          Модуль подготовлен под ваш новый сценарий. Далее сюда можно перенести интерактивные графики из мониторинга.
        </Typography>
      </Paper>
    </Box>
  );
};
