import React from 'react';
import { Chip, alpha, useTheme } from '@mui/material';
import { CheckCircle, Warning, Error, Info, Schedule } from '@mui/icons-material';

interface StatusBadgeProps {
  status: 'success' | 'warning' | 'error' | 'info' | 'pending' | 'running' | 'completed' | 'failed';
  label?: string;
  size?: 'small' | 'medium';
}

export const StatusBadge: React.FC<StatusBadgeProps> = ({ status, label, size = 'small' }) => {
  const theme = useTheme();

  const getStatusConfig = () => {
    switch (status) {
      case 'success':
      case 'completed':
        return { color: theme.palette.success.main, icon: <CheckCircle />, label: label || 'Success' };
      case 'warning':
      case 'pending':
        return { color: theme.palette.warning.main, icon: <Warning />, label: label || 'Pending' };
      case 'error':
      case 'failed':
        return { color: theme.palette.error.main, icon: <Error />, label: label || 'Failed' };
      case 'running':
        return { color: theme.palette.info.main, icon: <Schedule />, label: label || 'Running' };
      default:
        return { color: theme.palette.info.main, icon: <Info />, label: label || 'Info' };
    }
  };

  const config = getStatusConfig();

  return (
    <Chip
      icon={config.icon}
      label={config.label}
      size={size}
      sx={{
        bgcolor: alpha(config.color, 0.1),
        color: config.color,
        '& .MuiChip-icon': { color: config.color },
        fontWeight: 500,
      }}
    />
  );
};