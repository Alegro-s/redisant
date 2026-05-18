import React, { useCallback, useState } from 'react';
import { Alert, Box, Button, CircularProgress, Paper, Stack, Typography } from '@mui/material';
import api from '../../services/api';
import { useNotification } from '../../app/hooks/useNotification';
import { SchemaErDiagram } from './SchemaErDiagram';
import { useBaasConsole } from '../baas/BaasConsoleContext';

export const DatabaseSchemaPage: React.FC = () => {
  const { tables, schemaName } = useBaasConsole();
  const { showSuccess, showError } = useNotification();
  const [agentSchema, setAgentSchema] = useState<unknown>(null);
  const [agentSeen, setAgentSeen] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const loadAgentSchema = useCallback(async () => {
    setLoading(true);
    try {
      const r = await api.get('/me/agent/schema');
      setAgentSchema(r.data?.schema ?? null);
      setAgentSeen(r.data?.agent_last_seen ?? null);
      showSuccess('Схема обновлена');
    } catch {
      showError('Не удалось загрузить схему с агента');
    } finally {
      setLoading(false);
    }
  }, [showError, showSuccess]);

  const baasSchema =
    tables.length > 0
      ? Object.fromEntries(tables.map((t) => [t, { foreign_keys: [] }]))
      : null;

  const displaySchema = agentSchema ?? baasSchema;

  return (
    <Stack spacing={2}>
      <Paper sx={{ p: 2, borderRadius: 2 }}>
        <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
          ER-диаграмма
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          {schemaName
            ? `Схема BaaS: ${schemaName}. `
            : ''}
          Загрузите снимок с подключённого сервера (агент) или используйте список таблиц BaaS.
        </Typography>
        <Button variant="outlined" size="small" disabled={loading} onClick={() => void loadAgentSchema()}>
          {loading ? <CircularProgress size={18} /> : 'Обновить с сервера'}
        </Button>
        {agentSeen ? (
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>
            Последний heartbeat агента: {agentSeen}
          </Typography>
        ) : null}
      </Paper>

      {displaySchema ? (
        <SchemaErDiagram schema={displaySchema} />
      ) : (
        <Alert severity="info">
          Нет данных для диаграммы. Создайте таблицы в обзоре или подключите сервер с агентом.
        </Alert>
      )}
    </Stack>
  );
};
