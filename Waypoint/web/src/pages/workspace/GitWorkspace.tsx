import React from 'react';
import { Box, Chip, Paper, Stack, Typography } from '@mui/material';
import { Storage } from '@mui/icons-material';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';

export const GitWorkspace: React.FC = () => {
  const { capabilities } = useWorkspace();
  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
        Git Workspace
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2.5 }}>
        Управление репозиториями, квотами и историей синхронизации.
      </Typography>
      <Paper sx={{ p: 3, borderRadius: 3 }}>
        <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1 }}>
          <Storage color="primary" />
          <Typography sx={{ fontWeight: 600 }}>Текущие лимиты</Typography>
        </Stack>
        <Stack direction="row" spacing={1}>
          <Chip label={`Git: ${capabilities.gitGb} GB`} color="primary" />
          <Chip label={`Files: ${capabilities.storageGb} GB`} />
        </Stack>
      </Paper>
    </Box>
  );
};
