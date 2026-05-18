import React from 'react';
import {
  Box,
  Button,
  Card,
  CardActionArea,
  CardContent,
  Grid,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';
import { Storage, AccountTree, TableChart, Terminal, VpnKey } from '@mui/icons-material';
import { useBaasConsole } from '../baas/BaasConsoleContext';

const LINKS = [
  { to: '/dashboard/database/schema', title: 'ER-схема', desc: 'Связи таблиц и визуализация', icon: <AccountTree /> },
  { to: '/dashboard/database/tables', title: 'Таблицы', desc: 'Просмотр и правка строк', icon: <TableChart /> },
  { to: '/dashboard/database/sql', title: 'SQL-терминал', desc: 'Запросы к вашей БД', icon: <Terminal /> },
  { to: '/dashboard/database/api', title: 'API и ключи', desc: 'Секретный ключ и примеры curl', icon: <VpnKey /> },
];

export const DatabaseOverviewPage: React.FC = () => {
  const { schemaName, tables, newTable, setNewTable, onCreateTable, loading, refreshTables } = useBaasConsole();

  return (
    <Stack spacing={3}>
      <Card variant="outlined" sx={{ borderRadius: 2 }}>
        <CardContent>
          <Typography variant="h6" sx={{ fontWeight: 600, mb: 1 }}>
            Создать таблицу
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Быстрый старт: таблица с <code>id</code>, <code>data jsonb</code> и <code>created_at</code>. Дальше — REST или SQL.
          </Typography>
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'center' }}>
            <TextField
              size="small"
              label="Имя таблицы"
              value={newTable}
              onChange={(e) => setNewTable(e.target.value)}
              sx={{ minWidth: 200 }}
            />
            <Button variant="contained" disabled={loading || !newTable.trim()} onClick={() => void onCreateTable()}>
              Создать
            </Button>
            <Button variant="text" disabled={loading} onClick={() => void refreshTables()}>
              Обновить список
            </Button>
          </Stack>
          {tables.length > 0 && (
            <Typography variant="body2" sx={{ mt: 2 }}>
              Таблицы ({tables.length}): {tables.join(', ')}
            </Typography>
          )}
          {schemaName && tables.length === 0 && (
            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
              Схема {schemaName} готова — создайте первую таблицу.
            </Typography>
          )}
        </CardContent>
      </Card>

      <Grid container spacing={2}>
        {LINKS.map((l) => (
          <Grid item xs={12} sm={6} md={3} key={l.to}>
            <Card variant="outlined" sx={{ height: '100%', borderRadius: 2 }}>
              <CardActionArea component={RouterLink} to={l.to} sx={{ height: '100%' }}>
                <CardContent>
                  <Box sx={{ color: 'primary.main', mb: 1 }}>{l.icon}</Box>
                  <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                    {l.title}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    {l.desc}
                  </Typography>
                </CardContent>
              </CardActionArea>
            </Card>
          </Grid>
        ))}
        <Grid item xs={12} sm={6} md={3}>
          <Card variant="outlined" sx={{ height: '100%', borderRadius: 2 }}>
            <CardActionArea component={RouterLink} to="/dashboard/database/storage" sx={{ height: '100%' }}>
              <CardContent>
                <Box sx={{ color: 'primary.main', mb: 1 }}>
                  <Storage />
                </Box>
                <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                  Файлы
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  S3-совместимое хранилище
                </Typography>
              </CardContent>
            </CardActionArea>
          </Card>
        </Grid>
      </Grid>
    </Stack>
  );
};
