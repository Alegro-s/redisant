import React, { useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Chip,
  Divider,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import api from '../../services/api';
import { submitMeIngest } from '../../services/ingest.service';
import {
  cleanIngestPayload,
  defaultSimJson,
  ingestSimSamples,
  type SimulateResult,
} from './ingestLabShared';
import { CloudUpload } from '@mui/icons-material';
import { Link as RouterLink } from 'react-router-dom';

export const IngestLabSimulatePage: React.FC = () => {
  const [simJson, setSimJson] = useState(defaultSimJson);
  const [simResult, setSimResult] = useState<SimulateResult | null>(null);
  const [writeResult, setWriteResult] = useState<string | null>(null);
  const [error, setError] = useState('');
  const [writing, setWriting] = useState(false);

  const runSimulate = async () => {
    setError('');
    setSimResult(null);
    try {
      const parsed = JSON.parse(simJson);
      const body = cleanIngestPayload(parsed);
      const { data } = await api.post<SimulateResult>('/me/ingest/simulate', body);
      setSimResult(data);
    } catch (e: unknown) {
      const err = e as { message?: string; response?: { data?: { error?: string } } };
      setError(err.response?.data?.error || err.message || 'Ошибка JSON или сети');
    }
  };

  return (
    <>
      {error && (
        <Alert severity="warning" sx={{ mb: 2 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}
      <Paper sx={{ p: 2 }}>
        <Typography variant="subtitle2" gutterBottom>
          POST /me/ingest/simulate — без записи в БД; те же проверки, что при ingest
        </Typography>
        <Stack direction="row" gap={1} flexWrap="wrap" sx={{ mb: 2 }}>
          {Object.entries(ingestSimSamples).map(([label, json]) => (
            <Button key={label} size="small" variant="outlined" onClick={() => setSimJson(json)}>
              {label}
            </Button>
          ))}
          <Button size="small" onClick={() => setSimJson(defaultSimJson)}>
            Пример с ошибками
          </Button>
        </Stack>
        <TextField
          fullWidth
          multiline
          minRows={12}
          value={simJson}
          onChange={(e) => setSimJson(e.target.value)}
          sx={{ mb: 2, '& textarea': { fontFamily: 'monospace', fontSize: 13 } }}
        />
        <Stack direction="row" gap={1} flexWrap="wrap">
          <Button variant="contained" onClick={() => void runSimulate()}>
            Запустить симуляцию
          </Button>
          <Button
            variant="contained"
            color="success"
            startIcon={<CloudUpload />}
            disabled={writing}
            onClick={async () => {
              setError('');
              setWriteResult(null);
              setWriting(true);
              try {
                const parsed = JSON.parse(simJson);
                const body = cleanIngestPayload(parsed);
                const r = await submitMeIngest(body);
                setWriteResult(
                  `Записано: ${r.ingested_metrics} метрик, ${r.ingested_logs} логов → см. сводку и логи`,
                );
              } catch (e: unknown) {
                const err = e as { message?: string; response?: { data?: { error?: string } } };
                setError(err.response?.data?.error || err.message || 'Ошибка записи');
              } finally {
                setWriting(false);
              }
            }}
          >
            Записать в облако
          </Button>
          <Button component={RouterLink} to="/dashboard/ingest-lab/send" variant="outlined">
            Мастер записи
          </Button>
        </Stack>
        {writeResult && (
          <Alert severity="success" sx={{ mt: 2 }}>
            {writeResult}
          </Alert>
        )}

        {simResult && (
          <Box mt={3}>
            <Divider sx={{ mb: 2 }} />
            <Typography variant="subtitle1" gutterBottom>
              Результат
            </Typography>
            <Stack direction="row" gap={1} flexWrap="wrap" sx={{ mb: 2 }}>
              <Chip
                label={simResult.validation?.ok ? 'Валидация: OK' : 'Есть проблемы'}
                color={simResult.validation?.ok ? 'success' : 'error'}
                size="small"
              />
              <Chip
                label={`Примутся метрик: ${simResult.would_ingest?.metrics ?? 0} / пропуск: ${simResult.would_ingest?.skipped_metrics ?? 0}`}
                size="small"
              />
              <Chip
                label={`Логи: ${simResult.would_ingest?.logs ?? 0} / пропуск: ${simResult.would_ingest?.skipped_logs ?? 0}`}
                size="small"
              />
              <Chip
                label={`Алерт-логи: ${simResult.analysis?.logs_that_would_trigger_alert ?? 0}`}
                color={(simResult.analysis?.logs_that_would_trigger_alert ?? 0) > 0 ? 'warning' : 'default'}
                size="small"
              />
            </Stack>
            {simResult.validation?.warnings?.length ? (
              <Alert severity="info" sx={{ mb: 2 }}>
                {simResult.validation.warnings.join(' · ')}
              </Alert>
            ) : null}
            {simResult.validation?.issues?.length ? (
              <Alert severity="error" sx={{ mb: 2 }}>
                <Typography variant="subtitle2">Issues</Typography>
                <ul style={{ margin: '8px 0 0', paddingLeft: 18 }}>
                  {simResult.validation.issues.map((iss, i) => (
                    <li key={i}>
                      <code>{iss.code}</code> — {iss.message}
                      {iss.index != null ? ` (#${iss.index})` : ''}
                    </li>
                  ))}
                </ul>
              </Alert>
            ) : null}
            {simResult.analysis?.series_summary?.length ? (
              <>
                <Typography variant="subtitle2" sx={{ mt: 2, mb: 1 }}>
                  Агрегаты по имени (как после ingest нескольких точек)
                </Typography>
                <Box component="table" sx={{ width: '100%', borderCollapse: 'collapse', mb: 2, fontSize: 14 }}>
                  <Box component="thead">
                    <Box component="tr" sx={{ borderBottom: 1, borderColor: 'divider' }}>
                      {['Имя', 'N', 'min', 'max', 'avg', 'last'].map((h) => (
                        <Box component="th" key={h} sx={{ textAlign: h === 'Имя' ? 'left' : 'right', py: 1, pr: 1 }}>
                          {h}
                        </Box>
                      ))}
                    </Box>
                  </Box>
                  <Box component="tbody">
                    {simResult.analysis.series_summary.map((s) => (
                      <Box component="tr" key={s.name}>
                        <Box component="td" sx={{ py: 0.5 }}>
                          {s.name}
                        </Box>
                        <Box component="td" sx={{ textAlign: 'right' }}>
                          {s.count}
                        </Box>
                        <Box component="td" sx={{ textAlign: 'right' }}>
                          {s.min.toFixed(3)}
                        </Box>
                        <Box component="td" sx={{ textAlign: 'right' }}>
                          {s.max.toFixed(3)}
                        </Box>
                        <Box component="td" sx={{ textAlign: 'right' }}>
                          {s.avg.toFixed(3)}
                        </Box>
                        <Box component="td" sx={{ textAlign: 'right' }}>
                          {s.last.toFixed(3)}
                        </Box>
                      </Box>
                    ))}
                  </Box>
                </Box>
              </>
            ) : null}
            {simResult.analysis?.log_level_counts &&
              Object.keys(simResult.analysis.log_level_counts).length > 0 && (
                <Typography variant="body2" sx={{ mb: 1 }}>
                  Уровни логов:{' '}
                  {Object.entries(simResult.analysis.log_level_counts)
                    .map(([k, v]) => `${k}: ${v}`)
                    .join(', ')}
                </Typography>
              )}
            <Typography variant="caption" color="text.secondary" display="block" sx={{ mb: 1 }}>
              Админский preview того же отчёта: POST /api/waypoint/ai/analyze с телом{' '}
              <code>{`{ "target_type":"x","target":"y","ingest": { ... } }`}</code>
            </Typography>
            <Typography variant="subtitle2" gutterBottom>
              Сырой JSON
            </Typography>
            <Box
              component="pre"
              sx={{
                overflow: 'auto',
                bgcolor: 'grey.900',
                color: 'grey.100',
                p: 2,
                borderRadius: 1,
                fontSize: 12,
                maxHeight: 360,
              }}
            >
              {JSON.stringify(simResult, null, 2)}
            </Box>
          </Box>
        )}
      </Paper>
    </>
  );
};
