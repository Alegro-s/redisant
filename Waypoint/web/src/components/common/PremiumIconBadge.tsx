import React from 'react';
import { Box, alpha, useTheme } from '@mui/material';

interface PremiumIconBadgeProps {
  icon: React.ReactNode;
  active?: boolean;
  size?: number;
}

export const PremiumIconBadge: React.FC<PremiumIconBadgeProps> = ({
  icon,
  active = false,
  size = 30,
}) => {
  const theme = useTheme();
  return (
    <Box
      sx={{
        width: size,
        height: size,
        borderRadius: 1.8,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: active ? theme.palette.primary.main : theme.palette.text.secondary,
        background: active
          ? alpha(theme.palette.primary.main, 0.18)
          : alpha(theme.palette.primary.main, 0.08),
        border: `1px solid ${active ? alpha(theme.palette.primary.main, 0.36) : alpha(theme.palette.primary.main, 0.18)}`,
      }}
    >
      {icon}
    </Box>
  );
};
