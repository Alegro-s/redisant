import React from 'react';
import { Box, Button, Card, CardContent, Typography, alpha, useTheme } from '@mui/material';
import { LockOutlined } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { useWorkspace } from '../../app/contexts/WorkspaceContext';
import { hasPaidFeature, type PaidFeature } from '../../app/featureTiers';
import { WM_CLOUD } from '../layout/cloudShell';

interface FeatureGateProps {
  feature: PaidFeature;
  title: string;
  description: string;
  children: React.ReactNode;
}

export const FeatureGate: React.FC<FeatureGateProps> = ({ feature, title, description, children }) => {
  const theme = useTheme();
  const navigate = useNavigate();
  const { workspace } = useWorkspace();
  const allowed = hasPaidFeature(workspace.plan, feature);
  const isDark = theme.palette.mode === 'dark';

  if (allowed) return <>{children}</>;

  return (
    <Card
      sx={{
        borderRadius: 3,
        border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
        bgcolor: isDark ? alpha(WM_CLOUD.paperElevated, 0.35) : alpha(theme.palette.warning.main, 0.04),
      }}
    >
      <CardContent sx={{ p: 2.5, display: 'flex', gap: 2, alignItems: 'flex-start', flexWrap: 'wrap' }}>
        <Box
          sx={{
            width: 44,
            height: 44,
            borderRadius: 2,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            bgcolor: alpha(theme.palette.warning.main, 0.15),
            color: 'warning.main',
            flexShrink: 0,
          }}
        >
          <LockOutlined />
        </Box>
        <Box sx={{ flex: '1 1 240px', minWidth: 0 }}>
          <Typography variant="subtitle1" fontWeight={700}>
            {title}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5, lineHeight: 1.55 }}>
            {description} Доступно на плане Pro.
          </Typography>
          <Button variant="contained" size="small" sx={{ mt: 1.5 }} onClick={() => navigate('/dashboard/billing')}>
            Перейти к оплате
          </Button>
        </Box>
      </CardContent>
    </Card>
  );
};
