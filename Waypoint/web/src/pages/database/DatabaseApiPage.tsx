import React, { useMemo, useState } from 'react';
import {
  Accordion,
  AccordionDetails,
  AccordionSummary,
  Alert,
  Box,
  Button,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { ContentCopy, ExpandMore } from '@mui/icons-material';
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
  -H "X-API-Key: ${ingestKey ?? 'ВАШ_КЛЮЧ'}" \\
  -d '{"metrics":[{"name":"db.row","value":1}],"logs":[]}'`;

  const restGet = `curl -sS "${base}/api/me/baas/rest/${table}" \\
  -H "Authorization: Bearer <сессия>"`;

  const restPost = `curl -sS -X POST "${base}/api/me/baas/rest/${table}" \\
  -H "Authorization: Bearer <сессия>" \\
  -H "Content-Type: application/json" \\
  -d '{"hello":"world"}'`;

  const copy = (text: string) => {
    void navigator.clipboard.writeText(text);
    showSuccess('Скопировано');
  };

  const [showAdvanced, setShowAdvanced] = useState(false);

  return (
    <Stack spacing={2} sx={{ maxWidth: 720 }}>
      <Alert severity="info" sx={{ borderRadius: 2 }}>
        Ключ нужен, чтобы ваше приложение или сайт отправляли данные в облако. Управление — в разделе{' '}
        <RouterLink to="/dashboard/ingest-lab/keys-usage">Ключи метрик</RouterLink>.
      </Alert>

      <Paper sx={{ p: 2.5, borderRadius: 2 }}>
        <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
          Ключ подключения
        </Typography>
        {ingestKey ? (
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} alignItems={{ sm: 'center' }}>
            <TextField
              size="small"
              fullWidth
              value={ingestKey}
              InputProps={{ readOnly: true }}
            />
            <Button
              variant="contained"
              startIcon={<ContentCopy />}
              onClick={() => copy(ingestKey)}
              sx={{ flexShrink: 0, minWidth: { sm: 160 } }}
            >
              Копировать ключ
            </Button>
          </Stack>
        ) : (
          <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.55 }}>
            Ключ появится после настройки облака. Создайте его в{' '}
            <RouterLink to="/dashboard/ingest-lab/keys-usage">ключах метрик</RouterLink> или завершите{' '}
            <RouterLink to="/workspace/setup">настройку</RouterLink>.
          </Typography>
        )}
      </Paper>

      <Accordion
        expanded={showAdvanced}
        onChange={() => setShowAdvanced((v) => !v)}
        sx={{ borderRadius: 2, '&:before': { display: 'none' }, boxShadow: 'none', border: 1, borderColor: 'divider' }}
      >
        <AccordionSummary expandIcon={<ExpandMore />}>
          <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
            Для разработчиков — примеры запросов
          </Typography>
        </AccordionSummary>
        <AccordionDetails>
          <Stack spacing={2}>
            <Box>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                Отправка метрик
              </Typography>
              <Box component="pre" sx={{ p: 1.5, bgcolor: 'action.hover', borderRadius: 1, fontSize: 11, overflow: 'auto' }}>
                {ingestCurl}
              </Box>
              <Button size="small" sx={{ mt: 1 }} startIcon={<ContentCopy />} onClick={() => copy(ingestCurl)}>
                Копировать
              </Button>
            </Box>
            <Box>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                Чтение таблицы «{table}»
              </Typography>
              <Box component="pre" sx={{ p: 1.5, bgcolor: 'action.hover', borderRadius: 1, fontSize: 11, overflow: 'auto', mb: 1 }}>
                {restGet}
              </Box>
              <Box component="pre" sx={{ p: 1.5, bgcolor: 'action.hover', borderRadius: 1, fontSize: 11, overflow: 'auto' }}>
                {restPost}
              </Box>
              <Button size="small" sx={{ mt: 1 }} startIcon={<ContentCopy />} onClick={() => copy(restPost)}>
                Копировать
              </Button>
            </Box>
          </Stack>
        </AccordionDetails>
      </Accordion>

      <Button component={RouterLink} to="/dashboard/ingest-lab/keys-usage" variant="outlined" sx={{ alignSelf: 'flex-start' }}>
        Управление ключами
      </Button>
    </Stack>
  );
};
