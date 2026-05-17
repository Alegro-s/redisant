import React from 'react';
import { Box, Button, Stack, TextField, Typography } from '@mui/material';
import { useBaasConsole } from './BaasConsoleContext';

export const BaasSqlPage: React.FC = () => {
  const { sql, setSql, sqlResult, onRunSql, newTable, setNewTable, onCreateTable } = useBaasConsole();

  return (
    <Stack spacing={2}>
      <Typography variant="h6">SQL</Typography>
      <TextField
        label="SQL"
        value={sql}
        onChange={(e) => setSql(e.target.value)}
        multiline
        minRows={4}
        fullWidth
      />
      <Button variant="contained" onClick={() => void onRunSql()}>
        Выполнить
      </Button>
      <TextField label="Результат" value={sqlResult} multiline minRows={6} fullWidth InputProps={{ readOnly: true }} />

      <Typography variant="h6" sx={{ mt: 2 }}>
        Создать таблицу (DDL)
      </Typography>
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'center' }}>
        <TextField label="Имя таблицы" value={newTable} onChange={(e) => setNewTable(e.target.value)} />
        <Button variant="outlined" onClick={() => void onCreateTable()}>
          CREATE TABLE … (id uuid PK, data jsonb, created_at)
        </Button>
      </Stack>
      <Box sx={{ typography: 'caption', color: 'text.secondary' }}>
        Требует WM_BAAS_SQL_WRITE=1 и ADMIN_ALLOW_SQL_WRITE=1 на сервере.
      </Box>
    </Stack>
  );
};
