import React, { useMemo } from 'react';
import {
  Alert,
  Box,
  Button,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { ContentCopy } from '@mui/icons-material';
import { Link as RouterLink } from 'react-router-dom';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { useNotification } from '../../app/hooks/useNotification';
import { resolveApiBase } from '../../utils/apiBase';
import { useBaasConsole } from '../baas/BaasConsoleContext';

export const DatabaseApiPage: React.FC = () => {
  const { workspace } = useWorkspace();
  const { showSuccess } = useNotification();
  const { restTable, tables } = useBaasConsole();
  const base = useMemo(() => resolveApiBase().replace(/\/$/, ''), []);
  const ingestKey = workspace.ingestApiKey;
  const table = restTable || tables[0] || 'items';

  const ingestCurl = `curl -sS -X POST "${base}/api/waypoint/ingest" \\
  -H "Content-Type: application/json" \\
  -H "X-API-Key: ${ingestKey ?? 'ВАШ_СЕКРЕТНЫЙ_КЛЮЧ'}" \\
  -d '{"metrics":[{"name":"db.row","value":1}],"logs":[]}'`;

  const restGet = `curl -sS "${base}/api/me/baas/rest/${table}" \\
  -H "Authorization: Bearer <JWT_сессии>"`;

  const restPost = `curl -sS -X POST "${base}/api/me/baas/rest/${table}" \\
  -H "Authorization: Bearer <JWT_сессии>" \\
  -H "Content-Type: application/json" \\
  -d '{"hello":"world"}'`;

  const copy = (text: string) => {
    void navigator.clipboard.writeText(text);
    showSuccess('Скопировано');
  };

  return (
    <Stack spacing={2}>
      <Alert severity="info">
        Секретный ключ для ingest и внешних интеграций. Управление ключами (создать / отозвать) — в разделе ниже или в{' '}
        <RouterLink to="/dashboard/ingest-lab/keys-usage">полном редакторе ключей</RouterLink>.
      </Alert>

      <Paper sx={{ p: 2, borderRadius: 2 }}>
        <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
          Текущий ключ workspace
        </Typography>
        {ingestKey ? (
          <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap">
            <TextField
              size="small"
              fullWidth
              value={ingestKey}
              InputProps={{ readOnly: true, sx: { fontFamily: 'monospace', fontSize: 12 } }}
            />
            <Button startIcon={<ContentCopy />} onClick={() => copy(ingestKey)}>
              Копировать
            </Button>
          </Stack>
        ) : (
          <Typography variant="body2" color="text.secondary">
            Ключ ещё не выдан. Создайте в{' '}
            <RouterLink to="/dashboard/ingest-lab/keys-usage">редакторе ключей</RouterLink> или завершите настройку
            workspace.
          </Typography>
        )}
      </Paper>

      <Paper sx={{ p: 2, borderRadius: 2 }}>
        <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
          Ingest (метрики и логи)
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
          Заголовок <code>X-API-Key</code> — ваш секретный ключ.
        </Typography>
        <Box component="pre" sx={{ p: 1.5, bgcolor: 'action.hover', borderRadius: 1, fontSize: 11, overflow: 'auto' }}>
          {ingestCurl}
        </Box>
        <Button size="small" sx={{ mt: 1 }} startIcon={<ContentCopy />} onClick={() => copy(ingestCurl)}>
          Копировать curl
        </Button>
      </Paper>

      <Paper sx={{ p: 2, borderRadius: 2 }}>
        <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
          REST — таблицы BaaS
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
          Из браузера — с JWT (сессия после входа). Для серверных скриптов используйте ingest-ключ или сервисный токен.
        </Typography>
        <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 0.5 }}>
          GET строк
        </Typography>
        <Box component="pre" sx={{ p: 1.5, bgcolor: 'action.hover', borderRadius: 1, fontSize: 11, overflow: 'auto', mb: 1 }}>
          {restGet}
        </Box>
        <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 0.5 }}>
          POST строка (jsonb)
        </Typography>
        <Box component="pre" sx={{ p: 1.5, bgcolor: 'action.hover', borderRadius: 1, fontSize: 11, overflow: 'auto' }}>
          {restPost}
        </Box>
        <Button size="small" sx={{ mt: 1 }} startIcon={<ContentCopy />} onClick={() => copy(restPost)}>
          Копировать POST
        </Button>
      </Paper>

      <Button component={RouterLink} to="/dashboard/ingest-lab/keys-usage" variant="outlined">
        Управление API-ключами и лимитами
      </Button>
    </Stack>
  );
};
