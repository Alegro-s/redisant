import React from 'react';
import {
  Box,
  Button,
  Grid,
  Typography,
  Paper,
  Chip,
  alpha,
  useTheme,
  Alert,
} from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { WM_CLOUD } from '../../components/layout/cloudShell';
import { hubZones } from '../../components/layout/metricNavConfig';

export const WorkspaceHubPage: React.FC = () => {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';
  const { workspace } = useWorkspace();
  const hasServer = workspace.serverConnected || workspace.setupMode === 'rent';

  return (
    <Box sx={{ maxWidth: 880, mx: 'auto' }}>
      <Paper
        elevation={0}
        sx={{
          p: { xs: 2, md: 3 },
          mb: 2.5,
          borderRadius: 3,
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
          background: isDark
            ? `linear-gradient(145deg, ${alpha(WM_CLOUD.paperElevated, 0.95)}, ${alpha(WM_CLOUD.canvas, 0.6)})`
            : alpha(theme.palette.primary.main, 0.06),
        }}
      >
        <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.03em', mb: 1 }}>
          Главная
        </Typography>
        <Typography variant="body1" color="text.secondary" sx={{ maxWidth: 520, lineHeight: 1.65, mb: 2 }}>
          Облако работает вместе с Waypoint Desktop на вашем компьютере. Выберите раздел ниже.
        </Typography>
        {!hasServer ? (
          <Alert severity="warning" sx={{ borderRadius: 2, mb: 0 }}>
            Сначала{' '}
            <Button component={RouterLink} to="/workspace/setup" size="small" sx={{ ml: 0.5, verticalAlign: 'baseline' }}>
              настройте облако
            </Button>
            — без этого база и метрики недоступны.
          </Alert>
        ) : (
          <Chip label="Облако подключено" color="success" size="small" variant="outlined" />
        )}
      </Paper>

      <Grid container spacing={2} alignItems="stretch">
        {hubZones.map((z) => {
          const locked = z.to.includes('/database') && !hasServer;
          return (
            <Grid item xs={12} sm={6} key={z.to} sx={{ display: 'flex' }}>
              <Paper
                component={RouterLink}
                to={locked ? '/workspace/setup' : z.to}
                elevation={0}
                sx={{
                  width: '100%',
                  minHeight: 160,
                  p: 2.5,
                  textDecoration: 'none',
                  color: 'inherit',
                  display: 'flex',
                  flexDirection: 'column',
                  opacity: locked ? 0.65 : 1,
                  pointerEvents: locked ? 'none' : 'auto',
                  border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
                  borderRadius: 3,
                  transition: 'border-color 0.3s ease, box-shadow 0.3s ease, transform 0.3s cubic-bezier(0.22,1,0.36,1)',
                  '&:hover': locked
                    ? {}
                    : {
                        borderColor: alpha(WM_CLOUD.accent, 0.55),
                        boxShadow: isDark ? '0 16px 40px rgba(0,0,0,0.4)' : '0 12px 32px rgba(52,182,122,0.14)',
                        transform: 'translateY(-4px)',
                      },
                }}
              >
                <Box sx={{ color: 'primary.main', mb: 1.5 }}>{z.icon}</Box>
                <Typography variant="h6" sx={{ fontWeight: 700, mb: 0.5, fontSize: '1.05rem' }}>
                  {z.title}
                </Typography>
                <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.55, flex: 1 }}>
                  {z.description}
                </Typography>
                {z.badge ? (
                  <Chip label={z.badge} size="small" sx={{ mt: 1.75, alignSelf: 'flex-start', height: 'auto', py: 0.5 }} />
                ) : null}
              </Paper>
            </Grid>
          );
        })}
      </Grid>
    </Box>
  );
};
