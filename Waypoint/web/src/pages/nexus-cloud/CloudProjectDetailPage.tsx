import React, { useCallback, useEffect, useState } from 'react';
import {
  Box,
  Breadcrumbs,
  Button,
  Link,
  Paper,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Tabs,
  TextField,
  Typography,
} from '@mui/material';
import { Link as RouterLink, useNavigate, useParams } from 'react-router-dom';
import {
  createCloudBuild,
  deleteCloudProject,
  getCloudProject,
  listProjectBuilds,
  patchCloudProject,
  type NexusCloudBuildJob,
  type NexusCloudProject,
} from '../../services/nexus-cloud.service';
import { useNotification } from '../../app/hooks/useNotification';
import { LYNX_CLOUD_DASH } from '../../constants/lynxRoutes';

export const CloudProjectDetailPage: React.FC = () => {
  const { projectId } = useParams<{ projectId: string }>();
  const navigate = useNavigate();
  const { showError, showSuccess } = useNotification();
  const [project, setProject] = useState<NexusCloudProject | null>(null);
  const [tab, setTab] = useState(0);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(false);
  const [builds, setBuilds] = useState<NexusCloudBuildJob[]>([]);
  const [buildRef, setBuildRef] = useState('main');
  const [buildLabel, setBuildLabel] = useState('');

  const load = useCallback(async () => {
    if (!projectId) return;
    setLoading(true);
    try {
      const p = await getCloudProject(projectId);
      setProject(p);
      setName(p.name);
      setDescription(p.description ?? '');
    } catch {
      showError('Проект не найден или нет доступа');
      setProject(null);
    } finally {
      setLoading(false);
    }
  }, [projectId, showError]);

  useEffect(() => {
    void load();
  }, [load]);

  const loadBuilds = useCallback(async () => {
    if (!projectId) return;
    try {
      const b = await listProjectBuilds(projectId);
      setBuilds(b);
    } catch {
      setBuilds([]);
    }
  }, [projectId]);

  useEffect(() => {
    if (tab === 2 && projectId) void loadBuilds();
  }, [tab, projectId, loadBuilds]);

  const queueBuild = async () => {
    if (!projectId) return;
    setLoading(true);
    try {
      await createCloudBuild(projectId, {
        ref_name: buildRef.trim() || undefined,
        label: buildLabel.trim() || undefined,
      });
      showSuccess('Сборка поставлена в очередь');
      await loadBuilds();
    } catch {
      showError('Не удалось создать сборку');
    } finally {
      setLoading(false);
    }
  };

  const save = async () => {
    if (!projectId) return;
    const n = name.trim();
    if (!n) return;
    setLoading(true);
    try {
      const p = await patchCloudProject(projectId, {
        name: n,
        description: description.trim() || null,
      });
      setProject(p);
      showSuccess('Сохранено');
    } catch {
      showError('Не удалось сохранить');
    } finally {
      setLoading(false);
    }
  };

  const remove = async () => {
    if (!projectId) return;
    if (!window.confirm('Удалить проект без восстановления?')) return;
    setLoading(true);
    try {
      await deleteCloudProject(projectId);
      showSuccess('Проект удалён');
      navigate(`${LYNX_CLOUD_DASH}/projects`);
    } catch {
      showError('Удаление не удалось');
    } finally {
      setLoading(false);
    }
  };

  if (!projectId) return null;

  return (
    <Box sx={{ pt: 1, maxWidth: 800, mx: 'auto' }}>
      <Breadcrumbs sx={{ mb: 2 }}>
        <Link component={RouterLink} to={`${LYNX_CLOUD_DASH}/projects`} underline="hover" color="inherit">
          Проекты
        </Link>
        <Typography color="text.primary">{project?.name ?? '…'}</Typography>
      </Breadcrumbs>

      <Typography variant="h6" gutterBottom>
        {project?.name ?? 'Загрузка…'}
      </Typography>

      <Tabs value={tab} onChange={(_, v) => setTab(v)} sx={{ mb: 2 }}>
        <Tab label="Обзор" />
        <Tab label="Настройки" />
        <Tab label="Сборки" />
      </Tabs>

      {tab === 0 && project && (
        <Paper sx={{ p: 2 }}>
          <Typography variant="body2" color="text.secondary" gutterBottom>
            ID: <code>{project.id}</code>
          </Typography>
          <Typography variant="body1" sx={{ mt: 1 }}>
            {project.description || 'Без описания'}
          </Typography>
          <Typography variant="caption" display="block" color="text.secondary" sx={{ mt: 2 }}>
            Создан: {new Date(project.created_at).toLocaleString()} · Обновлён:{' '}
            {new Date(project.updated_at).toLocaleString()}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 3 }}>
            Облачные сборки и артефакты подключаются к очереди Redis и worker из репозитория{' '}
            <code>lynx-cloud</code> — здесь карточка проекта для биллинга и командной работы; пайплайн расширяется без
            смены модели данных.
          </Typography>
        </Paper>
      )}

      {tab === 1 && (
        <Paper sx={{ p: 2 }}>
          <TextField
            fullWidth
            size="small"
            label="Название"
            value={name}
            onChange={(e) => setName(e.target.value)}
            sx={{ mb: 2 }}
          />
          <TextField
            fullWidth
            size="small"
            label="Описание"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            multiline
            minRows={3}
            sx={{ mb: 2 }}
          />
          <Box sx={{ display: 'flex', gap: 1, flexWrap: 'wrap' }}>
            <Button variant="contained" onClick={() => void save()} disabled={loading || !name.trim()}>
              Сохранить
            </Button>
            <Button color="error" variant="outlined" onClick={() => void remove()} disabled={loading}>
              Удалить проект
            </Button>
          </Box>
        </Paper>
      )}

      {tab === 2 && (
        <Paper sx={{ p: 2 }}>
          <Typography variant="subtitle2" gutterBottom>
            Новая сборка
          </Typography>
          <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1, mb: 2 }}>
            <TextField
              size="small"
              label="ref / ветка"
              value={buildRef}
              onChange={(e) => setBuildRef(e.target.value)}
              sx={{ minWidth: 140 }}
            />
            <TextField
              size="small"
              label="Метка (опционально)"
              value={buildLabel}
              onChange={(e) => setBuildLabel(e.target.value)}
              sx={{ minWidth: 200 }}
            />
            <Button variant="contained" onClick={() => void queueBuild()} disabled={loading}>
              POST в очередь
            </Button>
            <Button size="small" onClick={() => void loadBuilds()}>
              Обновить список
            </Button>
          </Box>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Статус</TableCell>
                <TableCell>Ref</TableCell>
                <TableCell>Создана</TableCell>
                <TableCell>Лог / ошибка</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {builds.map((b) => (
                <TableRow key={b.id}>
                  <TableCell>{b.status}</TableCell>
                  <TableCell>{b.ref_name || '—'}</TableCell>
                  <TableCell>{new Date(b.created_at).toLocaleString()}</TableCell>
                  <TableCell>{b.log_excerpt || b.error_message || '—'}</TableCell>
                </TableRow>
              ))}
              {builds.length === 0 && (
                <TableRow>
                  <TableCell colSpan={4}>
                    <Typography variant="body2" color="text.secondary">
                      Пока нет записей — создайте сборку выше.
                    </Typography>
                  </TableCell>
                </TableRow>
              )}
            </TableBody>
          </Table>
        </Paper>
      )}
    </Box>
  );
};
