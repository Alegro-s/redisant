import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Divider,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { useAuth } from '../../app/contexts/AuthContext';
import api from '../../services/api';

interface Artifact {
  url: string;
  sha256?: string;
}

interface Release {
  version: string;
  notes?: string;
  artifacts: Record<string, Artifact>;
}

interface Manifest {
  releases: Release[];
  recommended_version?: string | null;
  source?: string | null;
}

interface Policy {
  manifest_url: string | null;
  recommended_version: string | null;
  updated_at: string | null;
}


export const LynxCloudEnginePage: React.FC = () => {
  const { can } = useAuth();
  const canManage = can('versions:manage');

  const [manifest, setManifest] = useState<Manifest | null>(null);
  const [policy, setPolicy] = useState<Policy | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);

  const [manifestUrl, setManifestUrl] = useState('');
  const [recommendedVersion, setRecommendedVersion] = useState('');

  const loadAll = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const mRes = await api.get<Manifest>('/engine/manifest');
      setManifest(mRes.data);
      if (canManage) {
        const pRes = await api.get<Policy>('/admin/engine/policy');
        setPolicy(pRes.data);
        setManifestUrl(pRes.data.manifest_url ?? '');
        setRecommendedVersion(pRes.data.recommended_version ?? '');
      }
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Ошибка загрузки';
      setError(msg);
    } finally {
      setLoading(false);
    }
  }, [canManage]);

  useEffect(() => {
    void loadAll();
  }, [loadAll]);

  const savePolicy = async () => {
    if (!canManage || !policy) return;
    setSaving(true);
    setOk(null);
    setError(null);
    try {
      const body: Record<string, string> = {};
      if (manifestUrl !== (policy.manifest_url ?? '')) {
        body.manifest_url = manifestUrl;
      }
      if (recommendedVersion !== (policy.recommended_version ?? '')) {
        body.recommended_version = recommendedVersion;
      }
      if (Object.keys(body).length === 0) {
        setOk('Нет изменений для сохранения');
        setSaving(false);
        return;
      }
      await api.put('/admin/engine/policy', body);
      setOk('Сохранено. Клиенты и CI читают GET /engine/manifest');
      await loadAll();
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : 'Ошибка сохранения';
      setError(msg);
    } finally {
      setSaving(false);
    }
  };

  return (
    <Box>
      <Typography variant="h5" sx={{ fontWeight: 700, mb: 1 }}>
        Ядро Lynx — релизы и манифест
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
        Лаунчер и редактор забирают бинарники по <strong>GET /engine/manifest</strong> (без авторизации в API). Здесь — ваш
        личный просмотр релизов в кабинете <strong>Lynx Cloud</strong>; настройка политики поставки доступна команде
        платформы.
      </Typography>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}
      {ok && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setOk(null)}>
          {ok}
        </Alert>
      )}

      {canManage && (
        <Paper sx={{ p: 3, borderRadius: 2, mb: 3 }}>
          <Typography variant="subtitle1" sx={{ mb: 2, fontWeight: 600 }}>
            Политика поставки (платформа)
          </Typography>
          <TextField
            fullWidth
            label="URL манифеста (HTTPS JSON)"
            value={manifestUrl}
            onChange={(e) => setManifestUrl(e.target.value)}
            margin="normal"
            helperText="releases[], artifacts (windows, linux, …). Пусто — fallback из LYNX_ENGINE_MANIFEST_JSON на сервере (устар. имя env: NEXUS_ENGINE_MANIFEST_JSON)."
          />
          <TextField
            fullWidth
            label="Рекомендуемая версия (pin)"
            value={recommendedVersion}
            onChange={(e) => setRecommendedVersion(e.target.value)}
            margin="normal"
            helperText="Подставляется в ответ манифеста поверх JSON."
          />
          <Box sx={{ mt: 2, display: 'flex', gap: 1 }}>
            <Button variant="contained" onClick={() => void savePolicy()} disabled={saving}>
              {saving ? <CircularProgress size={22} /> : 'Сохранить'}
            </Button>
            <Button variant="outlined" onClick={() => void loadAll()} disabled={loading}>
              Обновить
            </Button>
          </Box>
          {policy?.updated_at && (
            <Typography variant="caption" display="block" sx={{ mt: 2 }} color="text.secondary">
              Политика обновлена: {new Date(policy.updated_at).toLocaleString()}
            </Typography>
          )}
        </Paper>
      )}

      <Paper sx={{ p: 3, borderRadius: 2 }}>
        <Typography variant="subtitle1" sx={{ mb: 2, fontWeight: 600 }}>
          Текущий манифест
        </Typography>
        {loading ? (
          <CircularProgress />
        ) : manifest ? (
          <>
            <Typography variant="body2" sx={{ mb: 1 }}>
              Источник: <code>{manifest.source ?? '—'}</code>
              {manifest.recommended_version ? ` · рекомендуется: ${manifest.recommended_version}` : ''}
            </Typography>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Версия</TableCell>
                  <TableCell>Заметки</TableCell>
                  <TableCell>Платформы</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {manifest.releases.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={3}>
                      Нет релизов. Задайте URL манифеста в политике или переменную окружения на API-сервере.
                    </TableCell>
                  </TableRow>
                ) : (
                  manifest.releases.map((r) => (
                    <TableRow key={r.version}>
                      <TableCell>{r.version}</TableCell>
                      <TableCell>{r.notes ?? '—'}</TableCell>
                      <TableCell>
                        {Object.entries(r.artifacts)
                          .map(([p, a]) => `${p}: ${a.url}`)
                          .join(' · ') || '—'}
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
            <Divider sx={{ my: 2 }} />
            <Typography variant="caption" component="pre" sx={{ whiteSpace: 'pre-wrap', fontFamily: 'monospace' }}>
              {JSON.stringify(manifest, null, 2)}
            </Typography>
          </>
        ) : (
          <Typography color="text.secondary">Нет данных</Typography>
        )}
      </Paper>
    </Box>
  );
};
