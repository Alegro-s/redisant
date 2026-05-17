import React from 'react';
import {
  AreaChart,
  Area,
  Line,
  ComposedChart,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';
import { useTheme, alpha, Box, Typography } from '@mui/material';

interface DataPoint {
  time: string;
  cpu: number;
  memory: number;
  total_memory: number;
  requests?: number;
}

interface CpuMemoryChartProps {
  data: DataPoint[];
  height?: number;
  showRequests?: boolean;
}


const CHART_SERIES_VIOLET = '#8B5CF6';

export const CpuMemoryChart: React.FC<CpuMemoryChartProps> = ({
  data,
  height = 300,
  showRequests = false,
}) => {
  const theme = useTheme();

  const chartData = data.map(item => ({
    ...item,
    memory_percent:
      item.total_memory > 0 ? (item.memory / item.total_memory) * 100 : 0,
  }));

  return (
    <Box>
      <Typography variant="subtitle2" sx={{ mb: 2, fontWeight: 600 }}>
        CPU & Memory Usage
      </Typography>
      <ResponsiveContainer width="100%" height={height}>
        <ComposedChart data={chartData}>
          <defs>
            <linearGradient id="cpuGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor={theme.palette.primary.main} stopOpacity={0.3}/>
              <stop offset="95%" stopColor={theme.palette.primary.main} stopOpacity={0}/>
            </linearGradient>
            <linearGradient id="memoryGradient" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%" stopColor={CHART_SERIES_VIOLET} stopOpacity={0.3}/>
              <stop offset="95%" stopColor={CHART_SERIES_VIOLET} stopOpacity={0}/>
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke={theme.palette.divider} />
          <XAxis 
            dataKey="time" 
            stroke={theme.palette.text.secondary}
            tick={{ fontSize: 12 }}
          />
          <YAxis 
            yAxisId="left"
            stroke={theme.palette.text.secondary}
            tick={{ fontSize: 12 }}
            label={{ value: 'Usage (%)', angle: -90, position: 'insideLeft', style: { fill: theme.palette.text.secondary } }}
          />
          {showRequests && (
            <YAxis 
              yAxisId="right"
              orientation="right"
              stroke={theme.palette.warning.main}
              tick={{ fontSize: 12 }}
              label={{ value: 'Requests', angle: 90, position: 'insideRight', style: { fill: theme.palette.warning.main } }}
            />
          )}
          <Tooltip
            contentStyle={{
              borderRadius: 12,
              backgroundColor: theme.palette.background.paper,
              border: `1px solid ${theme.palette.divider}`,
            }}
          />
          <Legend />
          <Area
            yAxisId="left"
            type="monotone"
            dataKey="cpu"
            stroke={theme.palette.primary.main}
            fill="url(#cpuGradient)"
            strokeWidth={2}
            name="CPU %"
          />
          <Area
            yAxisId="left"
            type="monotone"
            dataKey="memory_percent"
            stroke={CHART_SERIES_VIOLET}
            fill="url(#memoryGradient)"
            strokeWidth={2}
            name="Memory %"
          />
          {showRequests && (
            <Line
              yAxisId="right"
              type="monotone"
              dataKey="requests"
              stroke={theme.palette.warning.main}
              strokeWidth={2}
              dot={false}
              name="Requests"
            />
          )}
        </ComposedChart>
      </ResponsiveContainer>
    </Box>
  );
};