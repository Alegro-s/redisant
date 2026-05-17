import React from 'react';
import { Alert, Box, Chip, Paper, Stack, Typography } from '@mui/material';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';

export const RealtimeOps: React.FC = () => {
  const { capabilities } = useWorkspace();
  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
        Realtime Ops
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 2.5 }}>
        Мониторинг и управление работой в реальном времени.
      </Typography>
      <Paper sx={{ p: 3, borderRadius: 3 }}>
        <Stack direction="row" spacing={1} sx={{ mb: 2 }}>
          <Chip label={`vCPU: ${capabilities.vcpu}`} color="primary" />
          <Chip label={`Realtime: ${capabilities.realtime ? 'on' : 'off'}`} />
        </Stack>
        {!capabilities.realtime && (
          <Alert severity="info">Для realtime функций переключитесь на Pro или роль Admin.</Alert>
        )}
      </Paper>
    </Box>
  );
};
