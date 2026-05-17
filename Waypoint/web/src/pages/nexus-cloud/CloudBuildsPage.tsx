import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Link,
  Paper,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Typography,
  CircularProgress,
} from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';
import { listMyCloudBuilds, type NexusCloudBuildJob } from '../../services/nexus-cloud.service';
import { LYNX_CLOUD_DASH } from '../../constants/lynxRoutes';
import { useNotification } from '../../app/hooks/useNotification';

export const CloudBuildsPage: React.FC = () => {
  const { showError } = useNotification();
  const [builds, setBuilds] = useState<NexusCloudBuildJob[]>([]);
  const [loading, setLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const b = await listMyCloudBuilds();
      setBuilds(b);
    } catch {
      showError('Не удалось загрузить сборки');
    } finally {
      setLoading(false);
    }
  }, [showError]);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <Box sx={{ pt: 1, maxWidth: 960, mx: 'auto' }}>
      <Alert severity="info" sx={{ mb: 2 }}>
        POST <code>/me/lynx-cloud/projects/&#123;id&#125;/builds</code> ставит задачу в БД и пушит JSON в Redis-список{' '}
        <code>nexus-cloud-simple-build-queue</code>. Воркер (<code>nexus-cloud/worker</code> в репозитории) снимает задачу и может
        отчитаться в <code>POST /integrations/lynx-cloud/build-report</code> с заголовком{' '}
        <code>X-Lynx-Build-Worker-Secret</code> (устаревший alias: <code>X-Nexus-Build-Worker-Secret</code>).
      </Alert>
      <Paper sx={{ p: 2 }}>
        <Typography variant="subtitle2" gutterBottom sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
          Все сборки аккаунта
          {loading ? <CircularProgress size={18} /> : null}
        </Typography>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Статус</TableCell>
              <TableCell>Проект</TableCell>
              <TableCell>Ref / label</TableCell>
              <TableCell>Создана</TableCell>
              <TableCell>Лог</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {builds.length === 0 && !loading ? (
              <TableRow>
                <TableCell colSpan={5}>
                  <Typography variant="body2" color="text.secondary">
                    Нет сборок — запустите из карточки проекта (вкладка «Сборки»).
                  </Typography>
                </TableCell>
              </TableRow>
            ) : (
              builds.map((b) => (
                <TableRow key={b.id}>
                  <TableCell>{b.status}</TableCell>
                  <TableCell>
                    <Link component={RouterLink} to={`${LYNX_CLOUD_DASH}/projects/${b.project_id}`} underline="hover">
                      {b.project_id.slice(0, 8)}…
                    </Link>
                  </TableCell>
                  <TableCell>
                    {b.ref_name || '—'} {b.label ? `· ${b.label}` : ''}
                  </TableCell>
                  <TableCell>{new Date(b.created_at).toLocaleString()}</TableCell>
                  <TableCell sx={{ maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis' }}>
                    {b.log_excerpt || b.error_message || '—'}
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </Paper>
    </Box>
  );
};
