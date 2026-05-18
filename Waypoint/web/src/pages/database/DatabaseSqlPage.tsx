import React from 'react';
import { Box, Divider, Stack, Typography } from '@mui/material';
import { BaasSqlPage } from '../baas/BaasSqlPage';
import { DatabaseServerSql } from './DatabaseServerSql';

export const DatabaseSqlPage: React.FC = () => (
  <Stack spacing={3}>
    <Box>
      <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 0.5 }}>
        SQL — ваша BaaS-база
      </Typography>
      <BaasSqlPage />
    </Box>
    <Divider />
    <Box>
      <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 0.5 }}>
        SQL — сервер PostgreSQL (чтение)
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Запросы к основной БД платформы через агента. Для записи нужна роль admin.
      </Typography>
      <DatabaseServerSql />
    </Box>
  </Stack>
);
