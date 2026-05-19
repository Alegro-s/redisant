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

const HUB_LINKS = [
  { to: '/dashboard/database/schema', title: 'Схема', desc: 'Как связаны таблицы', icon: <AccountTree /> },
  { to: '/dashboard/database/tables', title: 'Таблицы', desc: 'Просмотр и правка данных', icon: <TableChart /> },
  { to: '/dashboard/database/sql', title: 'Запросы', desc: 'Выполнить SQL', icon: <Terminal /> },
  { to: '/dashboard/database/api', title: 'Ключи', desc: 'Подключить приложение', icon: <VpnKey /> },
  { to: '/dashboard/database/storage', title: 'Файлы', desc: 'Хранилище документов', icon: <Storage /> },
] as const;

export const DatabaseOverviewPage: React.FC = () => {
  const {
    schemaName,
    tables,
    newTable,
    setNewTable,
    onCreateTable,
    loading,
    refreshTables,
    activeEnvironment,
  } = useBaasConsole();

  return (
    <Stack spacing={3}>
      <Card variant="outlined" sx={{ borderRadius: 2 }}>
        <CardContent sx={{ p: { xs: 2, sm: 2.5 } }}>
          <Typography variant="h6" sx={{ fontWeight: 600, mb: 0.5 }}>
            Новая таблица
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2, maxWidth: 520, lineHeight: 1.55 }}>
            {activeEnvironment
              ? `Подпроект «${activeEnvironment.name}». `
              : ''}
            Создайте таблицу в один клик — с полями для данных и даты.
          </Typography>
          <Stack
            direction={{ xs: 'column', sm: 'row' }}
            spacing={1.5}
            alignItems={{ xs: 'stretch', sm: 'center' }}
            sx={{ maxWidth: 480 }}
          >
            <TextField
              size="small"
              label="Название"
              placeholder="например orders"
              value={newTable}
              onChange={(e) => setNewTable(e.target.value)}
              fullWidth
            />
            <Button
              variant="contained"
              disabled={loading || !newTable.trim()}
              onClick={() => void onCreateTable()}
              sx={{ minWidth: { sm: 140 }, flexShrink: 0 }}
            >
              Создать
            </Button>
            <Button variant="text" disabled={loading} onClick={() => void refreshTables()} sx={{ flexShrink: 0 }}>
              Обновить
            </Button>
          </Stack>
          {tables.length > 0 && (
            <Typography variant="body2" sx={{ mt: 2 }}>
              Таблицы: {tables.join(', ')}
            </Typography>
          )}
          {schemaName && tables.length === 0 && (
            <Typography variant="body2" color="text.secondary" sx={{ mt: 1.5 }}>
              База готова — создайте первую таблицу.
            </Typography>
          )}
        </CardContent>
      </Card>

      <Grid container spacing={2} alignItems="stretch">
        {HUB_LINKS.map((l) => (
          <Grid item xs={12} sm={6} md={4} key={l.to} sx={{ display: 'flex' }}>
            <Card variant="outlined" sx={{ borderRadius: 2, width: '100%' }}>
              <CardActionArea
                component={RouterLink}
                to={l.to}
                sx={{
                  height: '100%',
                  minHeight: 132,
                  display: 'flex',
                  alignItems: 'stretch',
                }}
              >
                <CardContent sx={{ width: '100%' }}>
                  <Box sx={{ color: 'primary.main', mb: 1.25, display: 'flex' }}>{l.icon}</Box>
                  <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 0.35 }}>
                    {l.title}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.45 }}>
                    {l.desc}
                  </Typography>
                </CardContent>
              </CardActionArea>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Stack>
  );
};
