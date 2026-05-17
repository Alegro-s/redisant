import React from 'react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { useTheme, Box, Typography } from '@mui/material';

interface DiskChartProps {
  data: Array<{
    time: string;
    disk_io: number;
  }>;
  height?: number;
}

export const DiskChart: React.FC<DiskChartProps> = ({ data, height = 250 }) => {
  const theme = useTheme();

  return (
    <Box>
      <Typography variant="subtitle2" sx={{ mb: 2, fontWeight: 600 }}>
        Disk I/O (MB/s)
      </Typography>
      <ResponsiveContainer width="100%" height={height}>
        <BarChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke={theme.palette.divider} />
          <XAxis dataKey="time" stroke={theme.palette.text.secondary} tick={{ fontSize: 12 }} />
          <YAxis stroke={theme.palette.text.secondary} tick={{ fontSize: 12 }} />
          <Tooltip
            contentStyle={{
              borderRadius: 12,
              backgroundColor: theme.palette.background.paper,
              border: `1px solid ${theme.palette.divider}`,
            }}
          />
          <Bar
            dataKey="disk_io"
            fill={theme.palette.warning.main}
            radius={[4, 4, 0, 0]}
            name="Disk I/O"
          />
        </BarChart>
      </ResponsiveContainer>
    </Box>
  );
};