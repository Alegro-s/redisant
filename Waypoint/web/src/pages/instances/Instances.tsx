import React from 'react';
import { Box, Typography, Paper } from '@mui/material';

export const Instances: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3 }}>
        Instances
      </Typography>
      <Paper sx={{ p: 3, borderRadius: 3 }}>
        <Typography variant="body1" color="text.secondary">
          Instance management page - Coming soon
        </Typography>
      </Paper>
    </Box>
  );
};