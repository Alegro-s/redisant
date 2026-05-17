
use actix_web::{web, HttpResponse, Responder};
use prometheus::{Encoder, IntCounter, IntCounterVec, Opts, Registry, TextEncoder};

pub struct PrometheusHandles {
    pub registry: Registry,
    pub ingest_metrics_accepted: IntCounter,
    pub ingest_logs_accepted: IntCounter,
    pub ingest_metrics_rejected: IntCounter,
    pub ingest_logs_rejected: IntCounter,
    pub baas_rest_events: IntCounterVec,
}

impl PrometheusHandles {
    pub fn new() -> Result<Self, prometheus::Error> {
        let registry = Registry::new();
        let ingest_metrics_accepted = IntCounter::with_opts(Opts::new(
            "nexus_ingest_metrics_accepted_total",
            "Метрики, записанные в Postgres из POST ingest",
        ))?;
        let ingest_logs_accepted = IntCounter::with_opts(Opts::new(
            "nexus_ingest_logs_accepted_total",
            "Логи, записанные в Postgres из POST ingest",
        ))?;
        let ingest_metrics_rejected = IntCounter::with_opts(Opts::new(
            "nexus_ingest_metrics_rejected_total",
            "Метрики, отклонённые валидацией ingest",
        ))?;
        let ingest_logs_rejected = IntCounter::with_opts(Opts::new(
            "nexus_ingest_logs_rejected_total",
            "Логи, отклонённые валидацией ingest",
        ))?;
        let baas_rest_events = IntCounterVec::new(
            Opts::new(
                "nexus_baas_rest_events_total",
                "События BaaS REST (insert/update/delete), до pg_notify",
            ),
            &["op"],
        )?;
        registry.register(Box::new(ingest_metrics_accepted.clone()))?;
        registry.register(Box::new(ingest_logs_accepted.clone()))?;
        registry.register(Box::new(ingest_metrics_rejected.clone()))?;
        registry.register(Box::new(ingest_logs_rejected.clone()))?;
        registry.register(Box::new(baas_rest_events.clone()))?;
        Ok(Self {
            registry,
            ingest_metrics_accepted,
            ingest_logs_accepted,
            ingest_metrics_rejected,
            ingest_logs_rejected,
            baas_rest_events,
        })
    }
}

pub async fn metrics_http(state: web::Data<crate::AppState>) -> impl Responder {
    let m = match &state.prometheus {
        Some(h) => h,
        None => {
            return HttpResponse::ServiceUnavailable()
                .body("Prometheus registry not initialized\n");
        }
    };
    let metric_families = m.registry.gather();
    let mut buffer = Vec::new();
    let encoder = TextEncoder::new();
    if encoder.encode(&metric_families, &mut buffer).is_err() {
        return HttpResponse::InternalServerError().body("encode error\n");
    }
    HttpResponse::Ok()
        .content_type("text/plain; version=0.0.4; charset=utf-8")
        .body(buffer)
}
