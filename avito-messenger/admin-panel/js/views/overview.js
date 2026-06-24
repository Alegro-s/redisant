import { num, pct, bytes, uptime, ms, online } from "../lib/format.js";
import { renderTopologySection } from "../ui/topology-diagram.js";
import { sparkline, miniBars, detectionTimeline, readinessGauge, syntheticSeries } from "../ui/charts.js";

const NAV_ICONS = {
  overview: "◉",
  "ai-test": "◎",
  "shadow-mentor": "◇",
  users: "○",
  alerts: "△",
  notifications: "□",
  journal: "▤",
};

function stat(label, value, extra = "") {
  return `
    <div class="stat-cell">
      <div class="stat-label">${label}</div>
      <div class="stat-value">${value}${extra}</div>
    </div>
  `;
}

function kpi(label, value, sub = "", tone = "", chart = "") {
  const dark = tone === "dark" ? " workspace-kpi--dark" : tone === "accent" ? " workspace-kpi--accent" : "";
  return `
    <div class="workspace-kpi${dark}">
      <div class="workspace-kpi__label">${label}</div>
      <div class="workspace-kpi__value">${value}</div>
      ${sub ? `<div class="workspace-kpi__label">${sub}</div>` : ""}
      ${chart ? `<div class="workspace-kpi__chart">${chart}</div>` : ""}
    </div>
  `;
}

function bar(label, value, tone = "") {
  const v = Math.min(100, Math.max(0, Number(value) || 0));
  const cls = tone ? ` progress-fill--${tone}` : "";
  return `
    <div class="progress-row">
      <div class="progress-head"><span>${label}</span><span>${v}%</span></div>
      <div class="progress-track">
        <div class="progress-fill${cls}" style="width:${pct(v)}"></div>
      </div>
    </div>
  `;
}

function serviceRow(name, svc, { dashboardReady }) {
  const extra =
    name === "Мессенджер" && svc.usersLinked != null
      ? ` <span class="muted">(${svc.usersLinked}/${svc.usersTotal})</span>`
      : "";
  let chipClass = "chip--pending";
  let chipLabel = "проверка…";
  if (dashboardReady) {
    const on = online(svc);
    chipClass = on ? "chip--ok" : "chip--off";
    chipLabel = on ? "онлайн" : "офлайн";
  }
  const latency = dashboardReady ? ms(svc.latencyMs) : "—";
  const up = dashboardReady ? uptime(svc.uptimeSec) : "—";
  return `
    <tr>
      <td>${name}${extra}</td>
      <td><span class="chip ${chipClass}">${chipLabel}</span></td>
      <td>${latency}</td>
      <td>${up}</td>
    </tr>
  `;
}

function readinessPercent(state) {
  const prot = state.protection || {};
  if (prot.overallPct != null && Number.isFinite(prot.overallPct)) {
    return Math.round(Math.max(0, Math.min(100, prot.overallPct)));
  }
  const services = state.services || {};
  const security = state.security || {};
  const traffic = state.traffic || {};
  const keys = ["messenger", "gateway", "core", "database"];
  const on = keys.filter((k) => online(services[k])).length;
  let p = (on / keys.length) * 55;
  if ((traffic.analysesPending || 0) === 0) p += 15;
  if (security.alertsCritical === 0) p += 10;
  const lm = services.lmStudio;
  if (lm?.configured && !lm?.online) p = Math.min(p, 78);
  return Math.round(Math.max(0, Math.min(100, p)));
}

export function renderOverview(root, state, { loading, dashboardReady = false } = {}) {
  if (loading) return;

  const { meta, load, traffic, security, detection, services, topology } = state;
  const sync = meta.serverTime ? new Date(meta.serverTime).toLocaleString("ru-RU") : "—";
  const modeLabels = {
    local_only: "локально L1–L5",
    local_fallback: "локально (AI офлайн)",
    lm_studio_hybrid: "LM Studio + локально",
    ai_core_remote: "AI Core",
  };
  const coreMode = modeLabels[services.core?.mode] || services.core?.mode || "локально L1–L5";
  const coreOn = dashboardReady && online(services.core);
  const ready = dashboardReady ? readinessPercent(state) : 0;
  const readyLabel = dashboardReady ? `${Math.round(ready)}%` : "…";
  const coreLabel = dashboardReady ? (coreOn ? "online" : "offline") : "проверка…";
  const msgSeries = syntheticSeries(traffic.messagesPerMin * 10 || 12);
  const alertSeries = syntheticSeries(security.alertsOpen || 2);
  const layerBars = [
    detection.l1Hits24h,
    detection.l2Hits24h,
    detection.l3Hits24h,
    detection.l4Hits24h,
    detection.l5Hits24h,
  ];

  root.innerHTML = `
    <div class="meta-bar">
      <span class="meta-pill">v${meta.version || "—"}</span>
      <span class="meta-pill">API ${uptime(meta.uptimeSec)}</span>
      <span class="meta-pill">${sync}</span>
      <span class="meta-pill">${coreMode}</span>
    </div>

    <div class="dash-hero">
      ${kpi("Готовность", readyLabel, "индекс SOC", dashboardReady && ready > 70 ? "accent" : "", "")}
      ${kpi("Алерты", num(security.alertsOpen), `${num(security.alertsCritical)} крит.`, security.alertsCritical ? "dark" : "", sparkline(alertSeries))}
      ${kpi("Сообщений/мин", num(traffic.messagesPerMin, 2), `${num(traffic.messagesTotal)} всего`, "", sparkline(msgSeries))}
      ${kpi("Core", coreLabel, services.lmStudio?.configured ? "LM Studio" : "без LLM", dashboardReady && coreOn ? "" : dashboardReady ? "dark" : "", "")}
    </div>

    <div class="grid grid--2 section">
      <div class="card">
        <h3>Индикатор готовности</h3>
        <div class="readiness-row">
          ${readinessGauge(ready)}
          <div>
            <p><strong>${readyLabel}</strong> ${dashboardReady ? "система готова к защите" : "ожидание данных API…"}</p>
            <p class="muted">Очередь: ${num(traffic.analysesPending)} · БД: ${ms(load.latencyMs)}</p>
            ${bar("CPU", load.cpu, load.cpu > 85 ? "warn" : "")}
            ${bar("RAM", load.ram, load.ram > 85 ? "warn" : "")}
          </div>
        </div>
      </div>
      <div class="card">
        <h3>Активность (24ч)</h3>
        ${miniBars(layerBars, ["L1", "L2", "L3", "L4", "L5"], { h: 72 })}
        <p class="section-hint">Средний risk score: ${num(detection.avgScore24h, 1)}</p>
      </div>
    </div>

    <section class="section">
      <h3>Конвейер детекции L1–L6</h3>
      ${detectionTimeline(detection)}
    </section>

    ${renderTopologySection(topology, services, { dashboardReady })}

    <div class="grid grid--2 section">
      <section>
        <h3>Хост</h3>
        <div class="stat-grid stat-grid--3">
          ${stat("CPU", num(load.cpu), "%")}
          ${stat("RAM", num(load.ram), "%")}
          ${stat("Диск", num(load.disk), "%")}
        </div>
        <div class="stat-grid stat-grid--3" style="margin-top:12px">
          ${stat("Очередь", num(load.queue))}
          ${stat("GPU", num(load.gpu), "%")}
          ${stat("Трафик", bytes(traffic.bytesIn24h))}
        </div>
      </section>
      <section>
        <h3>Безопасность</h3>
        <div class="stat-grid stat-grid--3">
          ${stat("Блокировки", num(security.blocksActive))}
          ${stat("Риск", num(security.usersHighRisk))}
          ${stat("Юзеры", num(security.usersTotal))}
        </div>
      </section>
    </div>

    <section class="section">
      <h3>Сервисы</h3>
      <div class="card table-card">
        <table class="data-table">
          <thead>
            <tr><th>Сервис</th><th>Статус</th><th>Задержка</th><th>Аптайм</th></tr>
          </thead>
          <tbody>
            ${serviceRow("Мессенджер", { ...services.messenger, usersLinked: services.messenger?.usersLinked, usersTotal: services.messenger?.usersTotal }, { dashboardReady })}
            ${serviceRow("Gateway", services.gateway, { dashboardReady })}
            ${serviceRow("Core", services.core, { dashboardReady })}
            ${services.lmStudio?.configured ? serviceRow("LM Studio", services.lmStudio, { dashboardReady }) : ""}
            ${serviceRow("PostgreSQL", services.database, { dashboardReady })}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

export { NAV_ICONS };
