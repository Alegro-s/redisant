import React, { useState } from 'react';
import {
  Box,
  Button,
  FormControl,
  IconButton,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { Add, Delete, Refresh } from '@mui/icons-material';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { useBaasConsole } from '../baas/BaasConsoleContext';

export const DatabaseEnvironmentBar: React.FC = () => {
  const { workspace } = useWorkspace();
  const {
    environments,
    activeEnvironmentId,
    activeEnvironment,
    setActiveEnvironmentId,
    createEnvironment,
    deleteEnvironment,
    reloadEnvironments,
    loading,
    schemaName,
  } = useBaasConsole();
  const [newName, setNewName] = useState('');

  const hasServer = workspace.serverConnected || workspace.setupMode === 'rent';

  return (
    <Paper variant="outlined" sx={{ p: 2, mb: 2, borderRadius: 2 }}>
      <Stack spacing={1.5}>
        <Box>
          <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
            Подпроект (изолированная БД)
          </Typography>
          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', lineHeight: 1.45 }}>
            У каждого подпроекта своя база и папка с файлами: таблицы, запросы, схема и хранилище не
            пересекаются. Свой сервер подключается
            в{' '}
            <a href="/workspace/setup" style={{ color: 'inherit' }}>
              настройке workspace
            </a>{' '}
            — снимок схемы для ER подтягивается с агента на этом сервере.
          </Typography>
        </Box>

        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'center' }}>
          <FormControl size="small" sx={{ minWidth: 220, flex: 1 }} disabled={!hasServer}>
            <InputLabel id="baas-env-label">Подпроект</InputLabel>
            <Select
              labelId="baas-env-label"
              label="Подпроект"
              value={activeEnvironmentId ?? ''}
              onChange={(e) => setActiveEnvironmentId(e.target.value)}
            >
              {environments.map((env) => (
                <MenuItem key={env.id} value={env.id}>
                  {env.name}
                  {env.is_default ? ' (основной)' : ''}
                </MenuItem>
              ))}
            </Select>
          </FormControl>
          <Tooltip title="Обновить список">
            <IconButton size="small" onClick={() => void reloadEnvironments()} disabled={loading}>
              <Refresh fontSize="small" />
            </IconButton>
          </Tooltip>
          {activeEnvironment && !activeEnvironment.is_default ? (
            <Tooltip title="Удалить подпроект">
              <IconButton
                size="small"
                color="error"
                onClick={() => void deleteEnvironment(activeEnvironment.id)}
                disabled={loading}
              >
                <Delete fontSize="small" />
              </IconButton>
            </Tooltip>
          ) : null}
        </Stack>

        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} alignItems={{ sm: 'center' }}>
          <TextField
            size="small"
            label="Новый подпроект"
            placeholder="Магазин, CRM, тест…"
            value={newName}
            onChange={(e) => setNewName(e.target.value)}
            disabled={!hasServer}
            sx={{ flex: 1 }}
          />
          <Button
            variant="outlined"
            startIcon={<Add />}
            disabled={!hasServer || !newName.trim() || loading}
            onClick={() => {
              void createEnvironment(newName.trim()).then(() => setNewName(''));
            }}
          >
            Создать БД
          </Button>
        </Stack>

        {schemaName ? (
          <Typography variant="caption" color="text.secondary">
            База: {schemaName}
            {workspace.setupMode === 'connect' ? ' · подключён свой сервер' : null}
          </Typography>
        ) : null}
      </Stack>
    </Paper>
  );
};
