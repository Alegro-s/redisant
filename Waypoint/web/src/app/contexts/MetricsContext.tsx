import React, { createContext, useContext, useState, useEffect, ReactNode, useCallback } from 'react';
import { useAuth } from './AuthContext';
import api from '../../services/api';

interface MetricPoint {
  time: string;
  cpu: number;
  memory: number;
  total_memory: number;
  disk_io: number;
  network_rx: number;
  network_tx: number;
  requests: number;
}

interface MetricsContextType {
  metrics: MetricPoint[];
  latestMetrics: MetricPoint | null;
  isLoading: boolean;
  error: string | null;
  refreshMetrics: () => Promise<void>;
}

const MetricsContext = createContext<MetricsContextType | undefined>(undefined);

export const useMetrics = () => {
  const context = useContext(MetricsContext);
  if (!context) {
    throw new Error('useMetrics must be used within MetricsProvider');
  }
  return context;
};

interface MetricsProviderProps {
  children: ReactNode;
}

export const MetricsProvider: React.FC<MetricsProviderProps> = ({ children }) => {
  const [metrics, setMetrics] = useState<MetricPoint[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { isAuthenticated, can } = useAuth();
  const canViewMetrics = can('metrics:view');

  const refreshMetrics = useCallback(async () => {
    if (!isAuthenticated || !canViewMetrics) {
      setMetrics([]);
      setError(null);
      setIsLoading(false);
      return;
    }

    try {
      const { data } = await api.get<MetricPoint[]>('/me/system-metrics');
      setMetrics(Array.isArray(data) ? data : []);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unknown error');
    } finally {
      setIsLoading(false);
    }
  }, [isAuthenticated, canViewMetrics]);

  useEffect(() => {
    if (!isAuthenticated) {
      setIsLoading(false);
      return;
    }
    if (canViewMetrics) {
      refreshMetrics();
      const interval = setInterval(() => {
        if (document.visibilityState === 'visible') {
          void refreshMetrics();
        }
      }, 10000);
      return () => clearInterval(interval);
    }
    void refreshMetrics();
  }, [isAuthenticated, canViewMetrics, refreshMetrics]);

  const latestMetrics = metrics.length > 0 ? metrics[metrics.length - 1] : null;

  return (
    <MetricsContext.Provider
      value={{
        metrics,
        latestMetrics,
        isLoading,
        error,
        refreshMetrics,
      }}
    >
      {children}
    </MetricsContext.Provider>
  );
};