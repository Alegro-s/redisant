import React from 'react';
import { Box, Button, Paper, Stack, Typography } from '@mui/material';
import { Api } from '@mui/icons-material';

export const ApiHub: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
        API Hub
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2.5 }}>
        Единая точка для REST API, ключей интеграции и маршрутов.
      </Typography>
      <Paper sx={{ p: 3, borderRadius: 3 }}>
        <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1 }}>
          <Api color="primary" />
          <Typography sx={{ fontWeight: 600 }}>Быстрые действия</Typography>
        </Stack>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.2}>
          <Button variant="contained">Создать API ключ</Button>
          <Button variant="outlined">Открыть API docs</Button>
        </Stack>
      </Paper>
    </Box>
  );
};
