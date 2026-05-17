import React from 'react';
import { Box, Typography, LinearProgress, alpha, useTheme, Paper } from '@mui/material';
import { CheckCircle, Warning, Error } from '@mui/icons-material';

interface HealthGaugeProps {
  title: string;
  value: number;
  unit?: string;
  threshold?: number;
  warningThreshold?: number;
  icon?: React.ReactNode;
}

export const HealthGauge: React.FC<HealthGaugeProps> = ({
  title,
  value,
  unit = '%',
  threshold = 80,
  warningThreshold = 60,
  icon,
}) => {
  const theme = useTheme();

  const getColor = () => {
    if (value >= threshold) return theme.palette.error.main;
    if (value >= warningThreshold) return theme.palette.warning.main;
    return theme.palette.success.main;
  };

  const getIcon = () => {
    if (value >= threshold) return <Error sx={{ color: theme.palette.error.main }} />;
    if (value >= warningThreshold) return <Warning sx={{ color: theme.palette.warning.main }} />;
    return <CheckCircle sx={{ color: theme.palette.success.main }} />;
  };

  return (
    <Paper sx={{ p: 2, borderRadius: 3 }}>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
        <Typography variant="body2" color="text.secondary">
          {title}
        </Typography>
        {icon || getIcon()}
      </Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
        {value.toFixed(1)}{unit}
      </Typography>
      <LinearProgress
        variant="determinate"
        value={Math.min((value / 100) * 100, 100)}
        sx={{
          height: 8,
          borderRadius: 4,
          bgcolor: alpha(getColor(), 0.2),
          '& .MuiLinearProgress-bar': {
            borderRadius: 4,
            bgcolor: getColor(),
          },
        }}
      />
      {value >= threshold && (
        <Typography variant="caption" color="error.main" sx={{ mt: 1, display: 'block' }}>
          Critical - Immediate attention required
        </Typography>
      )}
    </Paper>
  );
};