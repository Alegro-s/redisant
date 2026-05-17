import React from 'react';
import { Box, Paper, Stack, Typography, alpha, useTheme } from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';

interface ModuleFeatureCardProps {
  title: string;
  description: React.ReactNode;
  icon: React.ReactNode;
  to: string;
  
  minHeight?: number;
}


export const ModuleFeatureCard: React.FC<ModuleFeatureCardProps> = ({
  title,
  description,
  icon,
  to,
  minHeight,
}) => {
  const theme = useTheme();
  const borderTop = theme.palette.divider;
  const borderSoft = alpha(theme.palette.divider, 0.45);

  return (
    <Box
      component={RouterLink}
      to={to}
      sx={{
        display: 'flex',
        height: '100%',
        textDecoration: 'none',
        color: 'inherit',
        borderRadius: 2,
        p: '1px',
        background: `linear-gradient(to bottom, ${borderTop}, ${borderSoft})`,
        transition: 'box-shadow 0.22s ease, background 0.22s ease, transform 0.22s ease',
        '&:hover': {
          boxShadow: `0 8px 24px ${alpha(theme.palette.common.black, 0.18)}`,
          background: alpha(theme.palette.primary.main, 0.22),
          transform: 'translateY(-2px)',
        },
        '&:focus-visible': {
          outline: `2px solid ${theme.palette.primary.main}`,
          outlineOffset: 2,
        },
      }}
    >
      <Paper
        elevation={0}
        sx={{
          position: 'relative',
          overflow: 'hidden',
          borderRadius: 1.75,
          flex: 1,
          width: '100%',
          minHeight: minHeight
            ? { xs: Math.min(minHeight, 200), sm: minHeight }
            : { xs: 200, sm: 260 },
          bgcolor: 'background.paper',
          border: 'none',
          display: 'flex',
          flexDirection: 'column',
          p: 2,
          pt: { sm: 2.5 },
        }}
      >
        <Stack
          direction="row"
          spacing={1.2}
          alignItems="center"
          sx={{ position: 'relative', zIndex: 2, mb: 1.25 }}
        >
          <Box
            sx={(t) => ({
              width: 40,
              height: 40,
              borderRadius: 1.5,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
              color: 'primary.main',
              bgcolor: alpha(t.palette.primary.main, 0.1),
              border: `1px solid ${alpha(t.palette.primary.main, 0.22)}`,
              '& svg': { fontSize: 22 },
            })}
          >
            {icon}
          </Box>
          <Typography variant="h6" sx={{ fontWeight: 700, fontSize: '1.05rem', lineHeight: 1.25 }}>
            {title}
          </Typography>
        </Stack>
        <Box sx={{ position: 'relative', zIndex: 2, flex: 1, display: 'flex', flexDirection: 'column' }}>
          <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.65, fontSize: '0.875rem', flex: 1 }}>
            {description}
          </Typography>
        </Box>

        {}
        <Box
          aria-hidden
          sx={{
            display: { xs: 'none', sm: 'block' },
            position: 'absolute',
            right: -24,
            bottom: -32,
            width: 180,
            height: 140,
            opacity: 0.22,
            borderRadius: 2,
            background: `linear-gradient(135deg, ${alpha(theme.palette.primary.main, 0.35)}, ${alpha(
              theme.palette.primary.dark,
              0.12,
            )})`,
            transform: 'rotate(-8deg)',
            pointerEvents: 'none',
          }}
        />
        <Box
          aria-hidden
          sx={{
            display: { xs: 'none', sm: 'block' },
            position: 'absolute',
            right: 48,
            bottom: 8,
            width: 56,
            height: 56,
            borderRadius: 1,
            border: `1px solid ${alpha(theme.palette.primary.main, 0.35)}`,
            bgcolor: alpha(theme.palette.primary.main, 0.06),
            pointerEvents: 'none',
          }}
        />
      </Paper>
    </Box>
  );
};
