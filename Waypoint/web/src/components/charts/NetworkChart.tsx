import React from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { useTheme, Box, Typography } from '@mui/material';

interface NetworkChartProps {
  data: Array<{
    time: string;
    network_rx: number;
    network_tx: number;
  }>;
  height?: number;
}

export const NetworkChart: React.FC<NetworkChartProps> = ({ data, height = 250 }) => {
  const theme = useTheme();

  return (
    <Box>
      <Typography variant="subtitle2" sx={{ mb: 2, fontWeight: 600 }}>
        Network Traffic (KB/s)
      </Typography>
      <ResponsiveContainer width="100%" height={height}>
        <AreaChart data={data}>
          <defs>
            <linearGradient id="rxGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor={theme.palette.success.main} stopOpacity={0.3}/>
              <stop offset="95%" stopColor={theme.palette.success.main} stopOpacity={0}/>
            </linearGradient>
            <linearGradient id="txGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor={theme.palette.info.main} stopOpacity={0.3}/>
              <stop offset="95%" stopColor={theme.palette.info.main} stopOpacity={0}/>
            </linearGradient>
          </defs>
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
          <Legend />
          <Area
            type="monotone"
            dataKey="network_rx"
            stroke={theme.palette.success.main}
            fill="url(#rxGradient)"
            strokeWidth={2}
            name="Download"
          />
          <Area
            type="monotone"
            dataKey="network_tx"
            stroke={theme.palette.info.main}
            fill="url(#txGradient)"
            strokeWidth={2}
            name="Upload"
          />
        </AreaChart>
      </ResponsiveContainer>
    </Box>
  );
};