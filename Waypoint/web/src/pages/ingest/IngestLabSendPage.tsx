import React, { useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Chip,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { CloudUpload, PlayArrow, Science } from '@mui/icons-material';
import { Link as RouterLink } from 'react-router-dom';
import { useNotification } from '../../app/hooks/useNotification';
import { cleanIngestPayload, defaultSimJson, ingestSimSamples } from './ingestLabShared';
import { quickDemoPayload, submitMeIngest, type IngestWriteResult } from '../../services/ingest.service';

export const IngestLabSendPage: React.FC = () => {
  const { showError, showSuccess } = useNotification();
  const [json, setJson] = useState(defaultSimJson);
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<IngestWriteResult | null>(null);
  const [error, setError] = useState('');

  const runWrite = async (body: unknown) => {
    setError('');
    setResult(null);
    setBusy(true);
    try {
      const cleaned = cleanIngestPayload(body);
      const data = await submitMeIngest(cleaned);
      setResult(data);
      showSuccess(
        `Записано: ${data.ingested_metrics} метрик, ${data.ingested_logs} логов. Откройте сводку или таблицу метрик.`,
      );
    } catch (e: unknown) {
      const err = e as { message?: string; response?: { data?: { error?: string } } };
      const msg = err.response?.data?.error || err.message || 'Ошибка записи';
      setError(msg);
      showError(msg);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Box>
      <Alert severity="success" sx={{ mb: 2 }}>
        Данные сохраняются в облако Metric — те же таблицы, что и при <code>POST /api/waypoint/ingest</code> с API-ключом.
        Вход по сессии, ключ в браузер не подставляется.
      </Alert>

      <Paper sx={{ p: 2, mb: 2 }}>
        <Typography variant="subtitle2" gutterBottom>
          Быстрый старт
        </Typography>
        <Stack direction="row" flexWrap="wrap" gap={1}>
          <Button
            variant="contained"
            startIcon={<PlayArrow />}
            disabled={busy}
            onClick={() => void runWrite(quickDemoPayload)}
          >
            Отправить демо-набор
          </Button>
          <Button
            variant="outlined"
            startIcon={<Science />}
            component={RouterLink}
            to="/dashboard/ingest-lab/simulate"
          >
            Сначала проверить (симуляция)
          </Button>
          <Button variant="outlined" component={RouterLink} to="/dashboard/ingest-lab/summary">
            Сводка метрик
          </Button>
          <Button variant="outlined" component={RouterLink} to="/dashboard/ingest-lab/logs">
            Журнал логов
          </Button>
        </Stack>
      </Paper>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}

      <Paper sx={{ p: 2 }}>
        <Typography variant="subtitle2" gutterBottom>
          POST /me/ingest — запись из JSON
        </Typography>
        <Stack direction="row" gap={1} flexWrap="wrap" sx={{ mb: 2 }}>
          {Object.entries(ingestSimSamples).map(([label, sample]) => (
            <Button key={label} size="small" variant="outlined" onClick={() => setJson(sample)}>
              {label}
            </Button>
          ))}
        </Stack>
        <TextField
          fullWidth
          multiline
          minRows={12}
          value={json}
          onChange={(e) => setJson(e.target.value)}
          sx={{ mb: 2, '& textarea': { fontFamily: 'monospace', fontSize: 13 } }}
        />
        <Button
          variant="contained"
          color="primary"
          startIcon={<CloudUpload />}
          disabled={busy}
          onClick={() => {
            try {
              void runWrite(JSON.parse(json));
            } catch {
              setError('Некорректный JSON');
            }
          }}
        >
          Записать в Metric
        </Button>

        {result && (
          <Box mt={3}>
            <Stack direction="row" gap={1} flexWrap="wrap">
              <Chip label={`Метрики: +${result.ingested_metrics}`} color="success" size="small" />
              <Chip label={`Логи: +${result.ingested_logs}`} color="success" size="small" />
              {(result.skipped_metrics ?? 0) > 0 && (
                <Chip label={`Пропуск метрик: ${result.skipped_metrics}`} size="small" />
              )}
              {(result.skipped_logs ?? 0) > 0 && (
                <Chip label={`Пропуск логов: ${result.skipped_logs}`} size="small" />
              )}
            </Stack>
          </Box>
        )}
      </Paper>
    </Box>
  );
};
