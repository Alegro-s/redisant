import React from 'react';
import { Skeleton, Box, Grid, Card, CardContent } from '@mui/material';

interface LoadingSkeletonProps {
  type?: 'card' | 'table' | 'chart' | 'list';
  count?: number;
}

export const LoadingSkeleton: React.FC<LoadingSkeletonProps> = ({ type = 'card', count = 1 }) => {
  if (type === 'card') {
    return (
      <Grid container spacing={3}>
        {Array.from({ length: count }).map((_, i) => (
          <Grid item xs={12} sm={6} md={3} key={i}>
            <Card>
              <CardContent>
                <Skeleton variant="text" width="60%" />
                <Skeleton variant="text" width="80%" height={40} />
                <Skeleton variant="text" width="40%" />
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
    );
  }

  if (type === 'table') {
    return (
      <Box>
        <Skeleton variant="rectangular" height={56} sx={{ mb: 1 }} />
        {Array.from({ length: count }).map((_, i) => (
          <Skeleton key={i} variant="rectangular" height={52} sx={{ mb: 1 }} />
        ))}
      </Box>
    );
  }

  if (type === 'chart') {
    return (
      <Box>
        <Skeleton variant="rectangular" height={300} sx={{ borderRadius: 2 }} />
      </Box>
    );
  }

  return (
    <Box>
      {Array.from({ length: count }).map((_, i) => (
        <Skeleton key={i} variant="text" height={60} sx={{ mb: 1 }} />
      ))}
    </Box>
  );
};