import React, { useEffect, useState } from 'react';
import { Link as RouterLink } from 'react-router-dom';
import {
  Box,
  Grid,
  Typography,
  useTheme,
  Button,
  IconButton,
  Tooltip,
  Alert,
  CircularProgress,
} from '@mui/material';
import { Refresh, Timeline, WarningAmber } from '@mui/icons-material';
import {
  Bar,
  BarChart,
  ResponsiveContainer,
  Tooltip as RechartsTooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { MetricCard } from '../../components/common/MetricCard';
import { CpuMemoryChart } from '../../components/charts/CpuMemoryChart';
import { NetworkChart } from '../../components/charts/NetworkChart';
import { DiskChart } from '../../components/charts/DiskChart';
import { HealthGauge } from '../../components/charts/HealthGauge';
import { useMetrics } from '../../app/contexts/MetricsContext';
import { useAuth } from '../../app/contexts/AuthContext';
import api from '../../services/api';
import {
  Memory,
  Storage,
  Wifi,
  People,
  Folder,
  Image,
  Schedule,
} from '@mui/icons-material';
import type { MetricsSummary } from '../../waypoint/ingestTypes';
import { PageSubNav } from '../../components/layout/PageSubNav';

interface Stats {
  users: number;
  projects: number;
  assets: number;
  active_sessions: number;
}

export const EnhancedDashboard: React.FC = () => {
  const theme = useTheme();
  const { metrics, latestMetrics, isLoading, error, refreshMetrics } = useMetrics();
  const { isAdmin } = useAuth();
  const [stats, setStats] = useState<Stats | null>(null);
  const [statsLoading, setStatsLoading] = useState(true);
  const [ingestSummary, setIngestSummary] = useState<MetricsSummary | null>(null);
  const [ingestSummaryLoading, setIngestSummaryLoading] = useState(true);
  const [ingestSummaryErr, setIngestSummaryErr] = useState<string | null>(null);

  useEffect(() => {
    if (!isAdmin) {
      setStats(null);
      setStatsLoading(false);
      return;
    }
    const fetchStats = async () => {
      try {
        const response = await api.get('/admin/stats');
        setStats(response.data);
      } catch (err) {
        console.error('Failed to fetch stats:', err);
      } finally {
        setStatsLoading(false);
      }
    };
    void fetchStats();
  }, [isAdmin]);

  useEffect(() => {
    const load = async () => {
      setIngestSummaryLoading(true);
      setIngestSummaryErr(null);
      try {
        const { data } = await api.get<MetricsSummary>('/me/metrics/summary');
        setIngestSummary(data);
      } catch {
        setIngestSummaryErr('Сводка метрик пока недоступна. Завершите настройку облака или подключите ключ в разделе «Ключи».');
        setIngestSummary(null);
      } finally {
        setIngestSummaryLoading(false);
      }
    };
    load();
  }, []);

  const chartData = metrics.map(m => ({
    time: new Date(m.time).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    cpu: m.cpu,
    memory: m.memory,
    total_memory: m.total_memory,
    network_rx: m.network_rx,
    network_tx: m.network_tx,
    disk_io: m.disk_io,
    requests: m.requests,
  }));

  const statsCards = [
    { title: 'Пользователи', value: stats?.users || 0, icon: <People />, color: '#3ECF8E', trend: 12 },
    { title: 'Проекты', value: stats?.projects || 0, icon: <Folder />, color: '#8B5CF6', trend: 5 },
    { title: 'Файлы', value: stats?.assets || 0, icon: <Image />, color: '#F59E0B', trend: 23 },
    { title: 'Сессии', value: stats?.active_sessions || 0, icon: <Schedule />, color: '#06B6D4', trend: -2 },
  ];

  if (isLoading && metrics.length === 0) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '80vh' }}>
        <CircularProgress size={60} thickness={4} />
      </Box>
    );
  }

  return (
    <Box>
      <PageSubNav
        items={[
          { label: 'Сводка', to: '/dashboard/overview', end: true },
          { label: 'Метрики', to: '/dashboard/ingest-lab/summary' },
          { label: 'База', to: '/dashboard/database' },
          { label: 'Подключение', to: '/dashboard/connect' },
          { label: 'Настройки', to: '/dashboard/settings' },
        ]}
      />
      {}
      <Box
        sx={{
          display: 'flex',
          flexDirection: { xs: 'column', sm: 'row' },
          justifyContent: 'space-between',
          alignItems: { xs: 'flex-start', sm: 'center' },
          gap: 2,
          mb: 4,
        }}
      >
        <Box>
          <Typography variant="h4" sx={{ fontWeight: 700, mb: 1, fontSize: { xs: '1.35rem', sm: '2rem' } }}>
            Сводка
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 720, lineHeight: 1.65 }}>
            {isAdmin
              ? 'Главные цифры по аккаунтам и нагрузке облака Waypoint Metric.'
              : 'Ваши события, метрики и состояние подключённого сервера в одном месте.'}
          </Typography>
        </Box>
        <Box sx={{ display: 'flex', gap: 1 }}>
          <Tooltip title="Обновить данные">
            <IconButton onClick={refreshMetrics} sx={{ bgcolor: theme.palette.background.paper }}>
              <Refresh />
            </IconButton>
          </Tooltip>
        </Box>
      </Box>

      {!isAdmin && (
        <Alert severity="info" sx={{ mb: 3 }}>
          Расширенные разделы для администраторов появятся после назначения прав на аккаунте.
        </Alert>
      )}

      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
        </Alert>
      )}

      {isAdmin && (
      <Grid container spacing={3} sx={{ mb: 4 }}>
        {statsCards.map((card) => (
          <Grid item xs={12} sm={6} md={3} key={card.title}>
            <MetricCard
              title={card.title}
              value={card.value}
              icon={card.icon}
              color={card.color}
              trend={card.trend}
              loading={statsLoading}
            />
          </Grid>
        ))}
      </Grid>
      )}

      <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
        События и метрики
      </Typography>
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12}>
          <Box
            sx={{
              bgcolor: 'background.paper',
              p: 2,
              borderRadius: 3,
              border: `1px solid ${theme.palette.divider}`,
            }}
          >
            <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2, flexWrap: 'wrap', gap: 1 }}>
              <Typography variant="subtitle1" sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                <Timeline fontSize="small" />
                Последние показатели из вашего облака
              </Typography>
              <Button component={RouterLink} to="/dashboard/ingest-lab/summary" variant="outlined" size="small">
                Открыть метрики
              </Button>
            </Box>
            {ingestSummaryErr && (
              <Alert severity="info" sx={{ mb: 2 }}>
                {ingestSummaryErr}
              </Alert>
            )}
            {ingestSummaryLoading && !ingestSummary && !ingestSummaryErr && (
              <Box sx={{ display: 'flex', justifyContent: 'center', py: 3 }}>
                <CircularProgress size={32} />
              </Box>
            )}
            {ingestSummary && (
              <>
                <Grid container spacing={2} sx={{ mb: 2 }}>
                  <Grid item xs={6} sm={3}>
                    <Typography variant="caption" color="text.secondary">
                      Всего точек
                    </Typography>
                    <Typography variant="h6">{ingestSummary.total_points}</Typography>
                  </Grid>
                  <Grid item xs={6} sm={3}>
                    <Typography variant="caption" color="text.secondary">
                      Уникальных имён
                    </Typography>
                    <Typography variant="h6">{ingestSummary.unique_metric_names}</Typography>
                  </Grid>
                  <Grid item xs={6} sm={3}>
                    <Typography variant="caption" color="text.secondary">
                      За 24 ч
                    </Typography>
                    <Typography variant="h6">{ingestSummary.points_last_24h}</Typography>
                  </Grid>
                  <Grid item xs={6} sm={3}>
                    <Typography variant="caption" color="text.secondary" sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                      <WarningAmber fontSize="inherit" />
                      Алерт-логи 24 ч
                    </Typography>
                    <Typography variant="h6" color={ingestSummary.alert_logs_last_24h > 0 ? 'warning.main' : 'text.primary'}>
                      {ingestSummary.alert_logs_last_24h}
                    </Typography>
                  </Grid>
                </Grid>
                {ingestSummary.latest_by_name.length > 0 ? (
                  <Box sx={{ height: 240 }}>
                    <ResponsiveContainer width="100%" height="100%">
                      <BarChart
                        data={ingestSummary.latest_by_name.map((r: MetricsSummary['latest_by_name'][number]) => ({
                          name: r.name,
                          value: r.value,
                        }))}
                      >
                        <XAxis dataKey="name" tick={{ fontSize: 11 }} interval={0} angle={-25} textAnchor="end" height={56} />
                        <YAxis tick={{ fontSize: 11 }} />
                        <RechartsTooltip />
                        <Bar dataKey="value" fill={theme.palette.primary.main} radius={[4, 4, 0, 0]} name="Последнее значение" />
                      </BarChart>
                    </ResponsiveContainer>
                  </Box>
                ) : (
                  <Typography variant="body2" color="text.secondary">
                    Пока нет данных. Отправьте первое событие из приложения или откройте раздел «Метрики».
                  </Typography>
                )}
              </>
            )}
          </Box>
        </Grid>
      </Grid>

      {!isLoading && (
        <>
      <Typography variant="h6" sx={{ mb: 2, fontWeight: 600 }}>
        Состояние сервера
      </Typography>
      <Alert severity="info" sx={{ mb: 2 }}>
        Здесь видна нагрузка на облако Waypoint Metric. Если подключили свой сервер — установите агент, чтобы видеть его
        отдельно.
      </Alert>
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <HealthGauge
            title="Процессор"
            value={latestMetrics?.cpu || 0}
            threshold={80}
            warningThreshold={60}
            icon={<Memory />}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <HealthGauge
            title="Память"
            value={
              latestMetrics && latestMetrics.total_memory > 0
                ? (latestMetrics.memory / latestMetrics.total_memory) * 100
                : 0
            }
            threshold={85}
            warningThreshold={70}
            icon={<Memory />}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <HealthGauge
            title="Диск"
            value={latestMetrics?.disk_io || 0}
            unit=" MB/s"
            threshold={100}
            warningThreshold={50}
            icon={<Storage />}
          />
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <HealthGauge
            title="Сеть"
            value={(latestMetrics?.network_rx || 0) + (latestMetrics?.network_tx || 0)}
            unit=" KB/s"
            threshold={5000}
            warningThreshold={2000}
            icon={<Wifi />}
          />
        </Grid>
      </Grid>

      <Grid container spacing={3}>
        <Grid item xs={12} lg={7}>
          <Box sx={{ bgcolor: 'background.paper', p: 2, borderRadius: 3, border: `1px solid ${theme.palette.divider}` }}>
            <CpuMemoryChart data={chartData} height={350} showRequests={isAdmin} />
          </Box>
        </Grid>
        <Grid item xs={12} lg={5}>
          <Box sx={{ bgcolor: 'background.paper', p: 2, borderRadius: 3, border: `1px solid ${theme.palette.divider}` }}>
            <Typography variant="subtitle2" sx={{ mb: 1, fontWeight: 600 }}>
              Активность
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
              Сколько обращений к облаку в секунду — по данным за последние минуты.
            </Typography>
            <Typography variant="h3" component="p" sx={{ fontWeight: 700 }}>
              {latestMetrics?.requests ?? 0}
              <Typography component="span" variant="body1" color="text.secondary" sx={{ ml: 1 }}>
                в секунду
              </Typography>
            </Typography>
          </Box>
        </Grid>
        <Grid item xs={12} md={6}>
          <Box sx={{ bgcolor: 'background.paper', p: 2, borderRadius: 3, border: `1px solid ${theme.palette.divider}` }}>
            <NetworkChart data={chartData} height={300} />
          </Box>
        </Grid>
        <Grid item xs={12} md={6}>
          <Box sx={{ bgcolor: 'background.paper', p: 2, borderRadius: 3, border: `1px solid ${theme.palette.divider}` }}>
            <DiskChart data={chartData} height={300} />
          </Box>
        </Grid>
      </Grid>
        </>
      )}
    </Box>
  );
};