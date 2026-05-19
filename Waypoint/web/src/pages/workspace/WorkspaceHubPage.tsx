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

      <Grid container spacing={2} alignItems="stretch">
        {zones.map((z) => (
          <Grid item xs={12} sm={6} key={z.to} sx={{ display: 'flex' }}>
            <Paper
              component={RouterLink}
              to={z.to}
              elevation={0}
              sx={{
                width: '100%',
                minHeight: 148,
                p: 2.25,
                textDecoration: 'none',
                color: 'inherit',
                display: 'flex',
                flexDirection: 'column',
                border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
                borderRadius: 2,
                transition: 'border-color 0.25s ease, box-shadow 0.25s ease, transform 0.25s ease',
                '&:hover': {
                  borderColor: alpha(WM_CLOUD.accent, 0.55),
                  boxShadow: isDark ? '0 12px 32px rgba(0,0,0,0.35)' : '0 8px 24px rgba(52,182,122,0.12)',
                  transform: 'translateY(-2px)',
                },
              }}
            >
              <Box sx={{ color: 'primary.main', mb: 1.25 }}>{z.icon}</Box>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 0.5 }}>
                {z.title}
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.55, flex: 1 }}>
                {z.description}
              </Typography>
              {z.badge ? (
                <Chip label={z.badge} size="small" sx={{ mt: 1.5, alignSelf: 'flex-start', height: 'auto', py: 0.5 }} />
              ) : null}
            </Paper>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
};
