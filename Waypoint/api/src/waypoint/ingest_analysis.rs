
use serde_json::json;

use super::ingest_payload::{
    dev_event_acceptable, log_acceptable, log_triggers_alert, metric_acceptable, normalize_dev_channel,
    IngestPayload, PayloadDevEvent, PayloadLog, PayloadMetric, MAX_DEV_EVENTS_PER_REQUEST,
};

#[derive(Debug, Clone, serde::Serialize)]
pub struct ValidationIssue {
    pub code: &'static str,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub index: Option<usize>,
}

fn collect_metric_issues(m: &PayloadMetric, index: usize) -> Vec<ValidationIssue> {
    let mut v = Vec::new();
    if m.name.trim().is_empty() {
        v.push(ValidationIssue {
            code: "empty_metric_name",
            message: "Имя метрики не может быть пустым".into(),
            index: Some(index),
        });
    } else if m.name.len() > super::ingest_payload::MAX_METRIC_NAME_LEN {
        v.push(ValidationIssue {
            code: "metric_name_too_long",
            message: format!(
                "Имя метрики длиннее {} символов",
                super::ingest_payload::MAX_METRIC_NAME_LEN
            ),
            index: Some(index),
        });
    }
    if !m.value.is_finite() {
        v.push(ValidationIssue {
            code: "non_finite_value",
            message: "Значение должно быть конечным числом (не NaN/Inf)".into(),
            index: Some(index),
        });
    }
    v
}

fn collect_dev_event_issues(e: &PayloadDevEvent, index: usize) -> Vec<ValidationIssue> {
    let mut v = Vec::new();
    let ch = e.channel.trim().to_lowercase();
    if ch.is_empty() {
        v.push(ValidationIssue {
            code: "empty_dev_event_channel",
            message: "Канал события не может быть пустым".into(),
            index: Some(index),
        });
    } else if ch.len() > 64 {
        v.push(ValidationIssue {
            code: "dev_event_channel_too_long",
            message: "Канал события длиннее 64 символов".into(),
            index: Some(index),
        });
    } else if !super::ingest_payload::DEV_EVENT_CHANNELS
        .iter()
        .any(|c| *c == ch.as_str())
    {
        v.push(ValidationIssue {
            code: "unknown_dev_event_channel",
            message: format!(
                "Неизвестный канал «{}». Допустимы: {}",
                ch,
                super::ingest_payload::DEV_EVENT_CHANNELS.join(", ")
            ),
            index: Some(index),
        });
    }
    let ev = e.event.trim();
    if ev.is_empty() {
        v.push(ValidationIssue {
            code: "empty_dev_event_name",
            message: "Имя события (event) не может быть пустым".into(),
            index: Some(index),
        });
    } else if ev.len() > super::ingest_payload::MAX_DEV_EVENT_NAME_LEN {
        v.push(ValidationIssue {
            code: "dev_event_name_too_long",
            message: format!(
                "Имя события длиннее {} символов",
                super::ingest_payload::MAX_DEV_EVENT_NAME_LEN
            ),
            index: Some(index),
        });
    }
    if let Some(val) = e.value {
        if !val.is_finite() {
            v.push(ValidationIssue {
                code: "dev_event_non_finite_value",
                message: "value должно быть конечным или отсутствовать".into(),
                index: Some(index),
            });
        }
    }
    v
}

fn collect_log_issues(l: &PayloadLog, index: usize) -> Vec<ValidationIssue> {
    let mut v = Vec::new();
    if l.message.trim().is_empty() {
        v.push(ValidationIssue {
            code: "empty_log_message",
            message: "Текст лога не может быть пустым".into(),
            index: Some(index),
        });
    } else if l.message.len() > super::ingest_payload::MAX_LOG_MESSAGE_LEN {
        v.push(ValidationIssue {
            code: "log_message_too_long",
            message: format!(
                "Сообщение лога длиннее {} символов",
                super::ingest_payload::MAX_LOG_MESSAGE_LEN
            ),
            index: Some(index),
        });
    }
    v
}

pub fn dry_run_report(payload: &IngestPayload) -> serde_json::Value {
    let mut issues = Vec::new();
    let mut would_ingest_metrics = 0usize;
    let mut would_skip_metrics = 0usize;

    for (i, m) in payload.metrics.iter().enumerate() {
        let row_issues = collect_metric_issues(m, i);
        if row_issues.is_empty() {
            would_ingest_metrics += 1;
        } else {
            would_skip_metrics += 1;
            issues.extend(row_issues);
        }
    }

    let mut would_ingest_logs = 0usize;
    let mut would_skip_logs = 0usize;
    let mut alert_logs = 0usize;
    if let Some(logs) = &payload.logs {
        for (i, l) in logs.iter().enumerate() {
            let row_issues = collect_log_issues(l, i);
            if row_issues.is_empty() {
                would_ingest_logs += 1;
                if log_triggers_alert(&l.level) {
                    alert_logs += 1;
                }
            } else {
                would_skip_logs += 1;
                issues.extend(row_issues);
            }
        }
    }

    let mut would_ingest_dev_events = 0usize;
    let mut would_skip_dev_events = 0usize;
    let mut truncated_dev_events = 0usize;
    let ev_slice: &[PayloadDevEvent] = if payload.events.len() > MAX_DEV_EVENTS_PER_REQUEST {
        truncated_dev_events = payload.events.len() - MAX_DEV_EVENTS_PER_REQUEST;
        &payload.events[..MAX_DEV_EVENTS_PER_REQUEST]
    } else {
        &payload.events[..]
    };
    for (i, e) in ev_slice.iter().enumerate() {
        if dev_event_acceptable(e) {
            would_ingest_dev_events += 1;
        } else {
            would_skip_dev_events += 1;
            issues.extend(collect_dev_event_issues(e, i));
        }
    }
    would_skip_dev_events += truncated_dev_events;

    let mut warnings = Vec::new();
    let logs_empty = payload.logs.as_ref().map_or(true, |l| l.is_empty());
    let no_events = payload.events.is_empty();
    if payload.metrics.is_empty() && logs_empty && no_events {
        warnings.push("Пустой батч: нет метрик, логов и событий".to_string());
    } else if payload.metrics.is_empty() && !no_events {
        warnings.push("Нет метрик — данные только в логах/событиях dev_events".to_string());
    } else if payload.metrics.is_empty() && !logs_empty {
        warnings.push("В батче нет метрик — в таблицу ingested_metrics ничего не попадёт".to_string());
    }

    let mut by_name: std::collections::BTreeMap<String, Vec<f64>> = std::collections::BTreeMap::new();
    for m in &payload.metrics {
        if metric_acceptable(m) {
            by_name.entry(m.name.clone()).or_default().push(m.value);
        }
    }

    let series_summary: Vec<serde_json::Value> = by_name
        .into_iter()
        .map(|(name, vals)| {
            let n = vals.len();
            let min = vals.iter().copied().fold(f64::INFINITY, f64::min);
            let max = vals.iter().copied().fold(f64::NEG_INFINITY, f64::max);
            let sum: f64 = vals.iter().sum();
            let avg = if n > 0 { sum / n as f64 } else { 0.0 };
            json!({
                "name": name,
                "count": n,
                "min": min,
                "max": max,
                "avg": avg,
                "last": vals.last().copied().unwrap_or(0.0),
            })
        })
        .collect();

    let mut level_counts: std::collections::BTreeMap<String, u32> = std::collections::BTreeMap::new();
    if let Some(logs) = &payload.logs {
        for l in logs {
            if log_acceptable(l) {
                *level_counts
                    .entry(l.level.to_lowercase())
                    .or_insert(0) += 1;
            }
        }
    }

    let preview_metrics: Vec<_> = payload
        .metrics
        .iter()
        .take(20)
        .map(|m| json!({"name": m.name, "value": m.value, "tags": m.tags, "acceptable": metric_acceptable(m)}))
        .collect();
    let preview_logs: Vec<_> = payload
        .logs
        .as_ref()
        .map(|logs| {
            logs.iter()
                .take(20)
                .map(|l| {
                    json!({
                        "level": l.level,
                        "message": l.message,
                        "tags": l.tags,
                        "acceptable": log_acceptable(l),
                        "would_alert": log_acceptable(l) && log_triggers_alert(&l.level),
                    })
                })
                .collect()
        })
        .unwrap_or_default();

    let dev_by_channel: std::collections::BTreeMap<String, u32> = ev_slice
        .iter()
        .filter(|e| dev_event_acceptable(e))
        .map(|e| normalize_dev_channel(&e.channel))
        .fold(std::collections::BTreeMap::new(), |mut acc, ch| {
            *acc.entry(ch).or_insert(0) += 1;
            acc
        });

    let preview_dev_events: Vec<_> = payload
        .events
        .iter()
        .take(20)
        .enumerate()
        .map(|(i, e)| {
            json!({
                "channel": e.channel,
                "event": e.event,
                "value": e.value,
                "properties": e.properties,
                "acceptable": dev_event_acceptable(e),
                "issues_preview": collect_dev_event_issues(e, i).len(),
            })
        })
        .collect();

    json!({
        "dry_run": true,
        "would_ingest": {
            "metrics": would_ingest_metrics,
            "logs": would_ingest_logs,
            "dev_events": would_ingest_dev_events,
            "skipped_metrics": would_skip_metrics,
            "skipped_logs": would_skip_logs,
            "skipped_dev_events": would_skip_dev_events,
        },
        "validation": {
            "ok": issues.is_empty(),
            "issues": issues,
            "warnings": warnings,
        },
        "analysis": {
            "unique_metric_names": series_summary.len(),
            "series_summary": series_summary,
            "log_level_counts": level_counts,
            "logs_that_would_trigger_alert": alert_logs,
            "dev_events_by_channel_acceptable_only": dev_by_channel,
        },
        "dashboard_projection": {
            "note": "После реального ingest те же точки попадут в «Мои метрики» и в сводку на дашборде",
            "estimated_new_total_delta_metrics": would_ingest_metrics,
            "estimated_new_total_delta_logs": would_ingest_logs,
            "estimated_new_total_delta_dev_events": would_ingest_dev_events,
        },
        "preview_metrics": preview_metrics,
        "preview_logs": preview_logs,
        "preview_dev_events": preview_dev_events,
        "ingest_url": "/api/waypoint/ingest",
        "header": "X-API-Key: <ваш ключ>",
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    fn sample_payload() -> IngestPayload {
        IngestPayload {
            timestamp: Some(Utc::now()),
            metrics: vec![
                PayloadMetric {
                    name: "cpu".into(),
                    value: 10.0,
                    tags: None,
                },
                PayloadMetric {
                    name: "cpu".into(),
                    value: 20.0,
                    tags: None,
                },
                PayloadMetric {
                    name: "".into(),
                    value: 1.0,
                    tags: None,
                },
                PayloadMetric {
                    name: "bad".into(),
                    value: f64::NAN,
                    tags: None,
                },
            ],
            logs: Some(vec![
                PayloadLog {
                    level: "info".into(),
                    message: "ok".into(),
                    tags: None,
                },
                PayloadLog {
                    level: "error".into(),
                    message: "boom".into(),
                    tags: None,
                },
            ]),
            events: vec![],
        }
    }

    #[test]
    fn dry_run_counts_skips_and_alerts() {
        let v = dry_run_report(&sample_payload());
        let wi = &v["would_ingest"];
        assert_eq!(wi["metrics"], 2);
        assert_eq!(wi["skipped_metrics"], 2);
        assert_eq!(wi["logs"], 2);
        assert_eq!(v["analysis"]["logs_that_would_trigger_alert"], 1);
        assert!(!v["validation"]["ok"].as_bool().unwrap());
    }

    #[test]
    fn series_avg_for_cpu() {
        let v = dry_run_report(&sample_payload());
        let series = v["analysis"]["series_summary"].as_array().unwrap();
        let cpu = series.iter().find(|s| s["name"] == "cpu").unwrap();
        assert_eq!(cpu["count"], 2);
        assert_eq!(cpu["avg"], 15.0);
    }
}
