import React from 'react';
import { Box, Grid, Typography, Paper, Chip, alpha, useTheme } from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';
import { useCabinetMode } from '../../app/contexts/CabinetModeContext';
import { WM_CLOUD } from '../../components/layout/cloudShell';
import { hubZones, infraHubZones } from '../../components/layout/metricNavConfig';

export const WorkspaceHubPage: React.FC = () => {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';
  const { mode } = useCabinetMode();
  const zones = mode === 'developer' ? [...hubZones, ...infraHubZones] : hubZones;

  return (
    <Box sx={{ maxWidth: 920, mx: 'auto' }}>
      <Paper
        elevation={0}
        sx={{
          p: { xs: 2, md: 2.5 },
          mb: 2.5,
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
          background: isDark ? alpha(WM_CLOUD.paperElevated, 0.85) : alpha(theme.palette.primary.main, 0.05),
        }}
      >
        <Typography variant="h5" sx={{ fontWeight: 700, mb: 0.75 }}>
          Рабочий стол
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 560, lineHeight: 1.6 }}>
          Облако Metric — базы, метрики и ключи. Привязка компьютера — здесь; проекты и терминал — в приложении Waypoint
          Desktop.
        </Typography>
      </Paper>

      <Grid container spacing={2}>
        {zones.map((z) => (
          <Grid item xs={12} sm={6} key={z.to}>
            <Paper
              component={RouterLink}
              to={z.to}
              elevation={0}
              sx={{
                height: '100%',
                p: 2,
                textDecoration: 'none',
                color: 'inherit',
                display: 'block',
                border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
                borderRadius: 2,
                '&:hover': { borderColor: alpha(WM_CLOUD.accent, 0.5) },
              }}
            >
              <Box sx={{ color: 'primary.main', mb: 1 }}>{z.icon}</Box>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 0.35 }}>
                {z.title}
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.5 }}>
                {z.description}
              </Typography>
              {z.badge ? (
                <Chip label={z.badge} size="small" sx={{ mt: 1.25, maxWidth: '100%', height: 'auto', py: 0.5 }} />
              ) : null}
            </Paper>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
};
