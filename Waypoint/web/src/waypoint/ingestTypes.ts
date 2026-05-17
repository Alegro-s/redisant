
export interface MetricsSummary {
  total_points: number;
  unique_metric_names: number;
  points_last_24h: number;
  alert_logs_last_24h: number;
  latest_by_name: Array<{ name: string; value: number; timestamp: string }>;
}

export interface ValidationIssue {
  code: string;
  message: string;
  index?: number;
}


export interface SimulateResult {
  dry_run?: boolean;
  would_ingest?: {
    metrics: number;
    logs: number;
    dev_events?: number;
    skipped_metrics?: number;
    skipped_logs?: number;
    skipped_dev_events?: number;
  };
  validation?: {
    ok: boolean;
    issues: ValidationIssue[];
    warnings: string[];
  };
  analysis?: {
    unique_metric_names: number;
    series_summary: Array<{
      name: string;
      count: number;
      min: number;
      max: number;
      avg: number;
      last: number;
    }>;
    log_level_counts: Record<string, number>;
    logs_that_would_trigger_alert: number;
  };
  dashboard_projection?: {
    note: string;
    estimated_new_total_delta_metrics: number;
    estimated_new_total_delta_logs: number;
  };
  preview_metrics?: Array<{
    name: string;
    value: number;
    tags?: unknown;
    acceptable?: boolean;
  }>;
  preview_logs?: Array<{
    level: string;
    message: string;
    tags?: unknown;
    acceptable?: boolean;
    would_alert?: boolean;
  }>;
  ingest_url?: string;
  header?: string;
}
