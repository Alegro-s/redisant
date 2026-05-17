import React, { useEffect, useRef } from 'react';
import { Navigate, Link as RouterLink } from 'react-router-dom';
import { useSnackbar } from 'notistack';
import { useAuth } from '../app/contexts/AuthContext';
import { useWorkspace } from '../app/contexts/WorkspaceContext';
import { CircularProgress, Box, Paper, Typography, Stack, Button } from '@mui/material';
import { Cloud, Link as LinkIcon } from '@mui/icons-material';
import { Permission } from '../app/authz';

interface PrivateRouteProps {
  children: React.ReactNode;
  adminOnly?: boolean;
  requiredPermission?: Permission;
  allowWithoutSetup?: boolean;
  requireServerConnection?: boolean;
}

export const PrivateRoute: React.FC<PrivateRouteProps> = ({
  children,
  adminOnly = false,
  requiredPermission,
  allowWithoutSetup = false,
  requireServerConnection = false,
}) => {
  const { isAuthenticated, isAdmin, isLoading, can } = useAuth();
  const { workspace, isLoading: workspaceLoading } = useWorkspace();
  const { enqueueSnackbar } = useSnackbar();
  const warnedRef = useRef(false);

  useEffect(() => {
    if (isLoading || !isAuthenticated || !adminOnly || isAdmin) return;
    if (warnedRef.current) return;
    warnedRef.current = true;
    enqueueSnackbar('Этот раздел доступен только администраторам WaypointMetric (роль admin).', {
      variant: 'warning',
      autoHideDuration: 5000,
    });
  }, [isLoading, isAuthenticated, adminOnly, isAdmin, enqueueSnackbar]);

  if (isLoading || workspaceLoading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  if ((adminOnly && !isAdmin) || (requiredPermission && !can(requiredPermission))) {
    return <Navigate to="/dashboard" replace />;
  }

  if (!allowWithoutSetup && !workspace.setupCompleted) {
    return <Navigate to="/workspace/setup" replace />;
  }

  const hasServerConnection =
    workspace.serverConnected || workspace.setupMode === 'rent' || workspace.plan === 'pro';

  if (requireServerConnection && !hasServerConnection) {
    return (
      <Box sx={{ minHeight: 'calc(100vh - 96px)', display: 'grid', placeItems: 'center', p: 2 }}>
        <Paper sx={{ p: { xs: 2.5, md: 3.5 }, maxWidth: 720, borderRadius: 3, textAlign: 'center' }}>
          <Stack spacing={1.4} alignItems="center">
            <Box sx={{ color: 'primary.main' }}>
              <Cloud />
            </Box>
            <Typography variant="h5" sx={{ fontWeight: 800 }}>
              Сначала подключите сервер
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 560 }}>
              Для модулей Database, API и Тестирования нужен активный сервер: аренда (Pro) или подключение своего
              хоста/IP в настройке рабочего пространства.
            </Typography>
            <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.2} sx={{ pt: 1 }}>
              <Button component={RouterLink} to="/workspace/setup" variant="contained" startIcon={<LinkIcon />}>
                Подключить или арендовать
              </Button>
              <Button component={RouterLink} to="/dashboard/overview" variant="outlined">
                Вернуться в обзор
              </Button>
            </Stack>
          </Stack>
        </Paper>
      </Box>
    );
  }

  return <>{children}</>;
};