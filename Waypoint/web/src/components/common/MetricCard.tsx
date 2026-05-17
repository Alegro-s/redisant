import React from 'react';
import { Card, CardContent, Typography, Box, Avatar, alpha, useTheme, Skeleton } from '@mui/material';
import { TrendingUp, TrendingDown } from '@mui/icons-material';

interface MetricCardProps {
  title: string;
  value: number | string;
  unit?: string;
  icon: React.ReactNode;
  color?: string;
  trend?: number;
  loading?: boolean;
  subtitle?: string;
}

export const MetricCard: React.FC<MetricCardProps> = ({
  title,
  value,
  unit,
  icon,
  color = '#3ECF8E',
  trend,
  loading = false,
  subtitle,
}) => {
  const theme = useTheme();

  if (loading) {
    return (
      <Card>
        <CardContent>
          <Skeleton variant="text" width="60%" />
          <Skeleton variant="text" width="80%" height={40} />
          <Skeleton variant="text" width="40%" />
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardContent>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <Box>
            <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 500 }}>
              {title}
            </Typography>
            <Typography variant="h3" sx={{ fontWeight: 700, mt: 1 }}>
              {typeof value === 'number' ? value.toLocaleString() : value}
              {unit && <Typography component="span" variant="body2" color="text.secondary"> {unit}</Typography>}
            </Typography>
            {trend !== undefined && (
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mt: 1 }}>
                {trend >= 0 ? (
                  <TrendingUp sx={{ fontSize: 14, color: theme.palette.success.main }} />
                ) : (
                  <TrendingDown sx={{ fontSize: 14, color: theme.palette.error.main }} />
                )}
                <Typography variant="caption" color={trend >= 0 ? 'success.main' : 'error.main'}>
                  {Math.abs(trend)}%
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  vs last week
                </Typography>
              </Box>
            )}
            {subtitle && (
              <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
                {subtitle}
              </Typography>
            )}
          </Box>
          <Avatar sx={{ bgcolor: alpha(color, 0.1), color, width: 48, height: 48 }}>
            {icon}
          </Avatar>
        </Box>
      </CardContent>
      <Box sx={{ height: 3, bgcolor: alpha(color, 0.2) }}>
        <Box sx={{ width: '70%', height: '100%', bgcolor: color, borderRadius: '0 4px 4px 0' }} />
      </Box>
    </Card>
  );
};