import React from 'react';
import { Box, Typography, Paper } from '@mui/material';

export const Jobs: React.FC = () => {
  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3 }}>
        Jobs
      </Typography>
      <Paper sx={{ p: 3, borderRadius: 3 }}>
        <Typography variant="body1" color="text.secondary">
          Job management page - Coming soon
        </Typography>
      </Paper>
    </Box>
  );
};