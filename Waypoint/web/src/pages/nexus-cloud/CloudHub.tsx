import React, { useCallback, useEffect, useState } from 'react';
import {
  Box,
  Button,
  IconButton,
  List,
  ListItem,
  ListItemButton,
  ListItemText,
  Paper,
  TextField,
  Typography,
} from '@mui/material';
import DeleteIcon from '@mui/icons-material/Delete';
import { Link as RouterLink } from 'react-router-dom';
import {
  createCloudProject,
  deleteCloudProject,
  listCloudProjects,
  NexusCloudProject,
} from '../../services/nexus-cloud.service';
import { LYNX_CLOUD_DASH } from '../../constants/lynxRoutes';
import { useNotification } from '../../app/hooks/useNotification';

export const CloudHub: React.FC = () => {
  const { showError, showSuccess } = useNotification();
  const [projects, setProjects] = useState<NexusCloudProject[]>([]);
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [loading, setLoading] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const p = await listCloudProjects();
      setProjects(p);
    } catch {
      showError('Не удалось загрузить проекты Lynx Cloud');
    } finally {
      setLoading(false);
    }
  }, [showError]);

  useEffect(() => {
    void load();
  }, [load]);

  const onCreate = async () => {
    const n = name.trim();
    if (!n) return;
    setLoading(true);
    try {
      await createCloudProject(n, description.trim() || undefined);
      showSuccess('Проект создан');
      setName('');
      setDescription('');
      await load();
    } catch {
      showError('Создание не удалось');
    } finally {
      setLoading(false);
    }
  };

  const onDelete = async (id: string) => {
    setLoading(true);
    try {
      await deleteCloudProject(id);
      showSuccess('Удалено');
      await load();
    } catch {
      showError('Удаление не удалось');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Box sx={{ pt: 1, maxWidth: 720, mx: 'auto' }}>
      <Paper sx={{ p: 2, mb: 2 }}>
        <Typography variant="subtitle2" gutterBottom>
          Новый проект
        </Typography>
        <TextField
          fullWidth
          size="small"
          label="Название"
          value={name}
          onChange={(e) => setName(e.target.value)}
          sx={{ mb: 1 }}
        />
        <TextField
          fullWidth
          size="small"
          label="Описание (необязательно)"
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          sx={{ mb: 1 }}
        />
        <Button variant="contained" onClick={() => void onCreate()} disabled={loading || !name.trim()}>
          Создать
        </Button>
      </Paper>

      <Paper>
        <List dense>
          {projects.map((p) => (
            <ListItem key={p.id} divider disablePadding secondaryAction={
              <IconButton edge="end" aria-label="delete" onClick={() => void onDelete(p.id)} disabled={loading}>
                <DeleteIcon />
              </IconButton>
            }>
              <ListItemButton component={RouterLink} to={`${LYNX_CLOUD_DASH}/projects/${p.id}`}>
                <ListItemText
                  primary={p.name}
                  secondary={
                    <>
                      {p.description || '—'}
                      <Typography component="span" variant="caption" display="block" color="text.secondary">
                        {new Date(p.updated_at).toLocaleString()}
                      </Typography>
                    </>
                  }
                />
              </ListItemButton>
            </ListItem>
          ))}
          {projects.length === 0 && (
            <ListItem>
              <ListItemText primary="Пока нет проектов" />
            </ListItem>
          )}
        </List>
      </Paper>
    </Box>
  );
};
