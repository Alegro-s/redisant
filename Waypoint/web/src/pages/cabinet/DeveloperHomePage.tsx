import React from 'react';
import { Box, Card, CardActionArea, CardContent, Grid, Stack, Typography, alpha, useTheme } from '@mui/material';
import { useNavigate } from 'react-router-dom';
import { WM_CLOUD } from '../../components/layout/cloudShell';
import { infraHubZones } from '../../components/layout/metricNavConfig';

/** Точка входа в серверную инфраструктуру (режим «Сервер»). */
export const DeveloperHomePage: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const isDark = theme.palette.mode === 'dark';

  return (
    <Stack spacing={2.5}>
      <Box
        sx={{
          borderRadius: 2,
          p: 2.5,
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
          background: isDark ? alpha(WM_CLOUD.paperElevated, 0.9) : theme.palette.background.paper,
        }}
      >
        <Typography variant="h5" sx={{ fontWeight: 700, mb: 0.75 }}>
          Сервер и инфраструктура
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ lineHeight: 1.6, maxWidth: 640 }}>
          Разработка в облаке: Lynx Cloud, BaaS, ingest. Локальная разработка — в Waypoint Desktop (проекты,
          Docker, терминал).
        </Typography>
      </Box>
      <Grid container spacing={2}>
        {infraHubZones.map((z) => (
          <Grid item xs={12} sm={6} key={z.to}>
            <Card
              sx={{
                borderRadius: 2,
                height: '100%',
                border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
              }}
            >
              <CardActionArea onClick={() => navigate(z.to)} sx={{ height: '100%' }}>
                <CardContent>
                  <Box sx={{ color: 'primary.main', mb: 1 }}>{z.icon}</Box>
                  <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                    {z.title}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
                    {z.description}
                  </Typography>
                </CardContent>
              </CardActionArea>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Stack>
  );
};
