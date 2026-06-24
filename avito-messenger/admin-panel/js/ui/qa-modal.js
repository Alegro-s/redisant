import { num, bytes, ms } from "../lib/format.js";
import { renderTopologySection } from "./topology-diagram.js";

function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function row(check) {
  const cls = check.ok ? "qa-row qa-row--ok" : "qa-row qa-row--fail";
  return `
    <tr class="${cls}">
      <td>${esc(check.group || "")}</td>
      <td>${esc(check.id || "")}</td>
      <td>${check.ok ? "OK" : "FAIL"}</td>
      <td>${check.ms != null ? check.ms : "—"}</td>
      <td>${esc(check.detail || "")}</td>
    </tr>
  `;
}

function normalizeLayer(l) {
  return {
    label: l.label,
    hits24h: l.hits_24h ?? l.hits24h ?? 0,
    sharePct: l.share_pct ?? l.sharePct ?? 0,
    activePct: l.active_pct ?? l.activePct ?? 0,
    healthPct: l.health_pct ?? l.healthPct ?? 0,
  };
}

function layerRow(l) {
  const x = normalizeLayer(l);
  return `
    <tr>
      <td>${esc(x.label)}</td>
      <td>${num(x.hits24h)}</td>
      <td>${num(x.sharePct, 1)}%</td>
      <td>${num(x.activePct, 1)}%</td>
      <td>${num(x.healthPct, 0)}%</td>
    </tr>
  `;
}

function checkGroupRows(checks) {
  const byGroup = new Map();
  (checks || []).forEach((c) => {
    const g = c.group || "other";
    const cur = byGroup.get(g) || { total: 0, ok: 0 };
    cur.total += 1;
    if (c.ok) cur.ok += 1;
    byGroup.set(g, cur);
  });
  return [...byGroup.entries()]
    .map(([group, stat]) => {
      const pctVal = stat.total ? Math.round((stat.ok / stat.total) * 100) : 0;
      return `
        <div class="qa-bar-row">
          <div class="qa-bar-head"><span>${esc(group)}</span><span>${stat.ok}/${stat.total} · ${pctVal}%</span></div>
          <div class="qa-bar-track"><div class="qa-bar-fill" style="width:${pctVal}%"></div></div>
        </div>
      `;
    })
    .join("");
}

function serviceRows(services) {
  const lm = services?.lmStudio || services?.lm_studio || {};
  const gatewayName = lm.configured ? "LM Studio" : "Gateway";
  const list = [
    ["Мессенджер", services?.messenger],
    [gatewayName, services?.gateway],
    ["Core (детекция)", services?.core],
    ["PostgreSQL", services?.database],
  ];
  return list
    .map(([name, svc]) => {
      const online = !!svc?.online;
      const latency = ms(svc?.latencyMs ?? svc?.latency_ms ?? 0);
      return `<tr><td>${name}</td><td><span class="chip ${online ? "chip--ok" : "chip--off"}">${online ? "ok" : "off"}</span></td><td>${latency}</td></tr>`;
    })
    .join("");
}

function readinessBlock(r, state) {
  const prot = r?.protection || state?.protection || {};
  const load = r?.load || state?.load || {};
  const traffic = r?.traffic || state?.traffic || {};
  const det = r?.detection || state?.detection || {};
  const host = r?.host || {};
  const overall = r?.overall_pct ?? r?.overallPct ?? prot.overall_pct ?? prot.overallPct ?? 0;
  const infra = r?.infra_pct ?? r?.infraPct ?? prot.infra_pct ?? prot.infraPct ?? 0;
  const coreOnline = !!(
    r?.core_online ??
    r?.coreOnline ??
    prot.core_online ??
    prot.coreOnline
  );
  const services = r?.services || state?.services || {};
  const topology = r?.topology || state?.topology || {};
  const checks = r?.checks || [];

  return `
    ${renderTopologySection(topology, services)}

    <section class="qa-section">
      <h3 class="qa-section-title">Готовность системы</h3>
      <div class="qa-readiness">
        <div class="qa-metric">
          <span class="stat-label">Общая готовность</span>
          <span class="stat-value qa-big">${num(overall)}%</span>
        </div>
        <div class="qa-metric">
          <span class="stat-label">Инфраструктура</span>
          <span class="stat-value">${num(infra)}%</span>
        </div>
        <div class="qa-metric">
          <span class="stat-label">Детекция L1–L5</span>
          <span class="chip ${coreOnline ? "chip--ok" : "chip--off"}">${coreOnline ? "активна" : "ошибка"}</span>
        </div>
      </div>
    </section>

    <section class="qa-section">
      <h3 class="qa-section-title">Графика прогона безопасности</h3>
      <div class="qa-visual-grid">
        <div class="qa-metric">
          <span class="stat-label">Защита (overall)</span>
          <div class="qa-gauge"><div class="qa-gauge-fill" style="width:${num(overall)}%"></div></div>
          <span class="stat-value">${num(overall)}%</span>
        </div>
        <div class="qa-metric">
          <span class="stat-label">Инфраструктура</span>
          <div class="qa-gauge"><div class="qa-gauge-fill qa-gauge-fill--infra" style="width:${num(infra)}%"></div></div>
          <span class="stat-value">${num(infra)}%</span>
        </div>
      </div>
      <div class="qa-bars">
        ${checkGroupRows(checks)}
      </div>
    </section>

    <section class="qa-section">
      <h3 class="qa-section-title">Сервер</h3>
      <div class="stat-grid stat-grid--4">
        <div class="stat-cell"><div class="stat-label">CPU</div><div class="stat-value">${num(load.cpu ?? host.cpu)}%</div></div>
        <div class="stat-cell"><div class="stat-label">RAM</div><div class="stat-value">${num(load.ram ?? host.ram)}%</div></div>
        <div class="stat-cell"><div class="stat-label">Диск</div><div class="stat-value">${num(load.disk ?? host.disk)}%</div></div>
        <div class="stat-cell"><div class="stat-label">БД</div><div class="stat-value">${ms(load.latencyMs)}</div></div>
      </div>
    </section>

    <section class="qa-section">
      <h3 class="qa-section-title">Состояние компонентов</h3>
      <table class="data-table">
        <thead><tr><th>Компонент</th><th>Статус</th><th>Latency</th></tr></thead>
        <tbody>${serviceRows(services)}</tbody>
      </table>
    </section>

    <section class="qa-section">
      <h3 class="qa-section-title">Трафик (с сервера)</h3>
      <div class="stat-grid stat-grid--4">
        <div class="stat-cell"><div class="stat-label">Сообщений</div><div class="stat-value">${num(traffic.messages_total ?? traffic.messagesTotal)}</div></div>
        <div class="stat-cell"><div class="stat-label">Анализов 24ч</div><div class="stat-value">${num(traffic.analyses_24h ?? traffic.analyses24h)}</div></div>
        <div class="stat-cell"><div class="stat-label">В очереди</div><div class="stat-value">${num(traffic.analyses_pending ?? traffic.analysesPending)}</div></div>
        <div class="stat-cell"><div class="stat-label">Объём 24ч</div><div class="stat-value">${bytes(traffic.bytes_in_24h ?? traffic.bytesIn24h)}</div></div>
      </div>
    </section>

    <section class="qa-section">
      <h3 class="qa-section-title">Защита — слои (24ч)</h3>
      <table class="data-table protection-table">
        <thead>
          <tr>
            <th>Слой</th>
            <th>Срабатывания</th>
            <th>Доля</th>
            <th>Охват</th>
            <th>Состояние</th>
          </tr>
        </thead>
        <tbody>
          ${(prot.layers || []).map(layerRow).join("")}
        </tbody>
      </table>
      <p class="section-hint">Срабатывания L1–L5: ${num(det.l1_hits_24h ?? det.l1Hits24h)} / ${num(det.l2_hits_24h ?? det.l2Hits24h)} / ${num(det.l3_hits_24h ?? det.l3Hits24h)} / ${num(det.l4_hits_24h ?? det.l4Hits24h)} / ${num(det.l5_hits_24h ?? det.l5Hits24h)} · средний score ${num(det.avg_score_24h ?? det.avgScore24h, 1)}</p>
    </section>
  `;
}

export function openQaModal() {
  const el = document.getElementById("modal-qa");
  if (el) el.showModal();
}

export function closeQaModal() {
  document.getElementById("modal-qa")?.close();
}

export function renderQaLoading() {
  const body = document.getElementById("qa-body");
  if (body) body.innerHTML = `<p class="qa-status">Проверка сервера и слоёв защиты…</p>`;
}

export function renderQaResult(data, state) {
  const body = document.getElementById("qa-body");
  if (!body || !data) return;
  const s = data.summary || {};
  const r = { ...(data.readiness || {}), checks: data.checks || [] };
  const head = data.ok
    ? `<p class="qa-status qa-status--ok">Проверок: ${s.passed}/${s.total}</p>`
    : `<p class="qa-status qa-status--fail">Сбоев: ${s.failed} из ${s.total}</p>`;
  const rows = (data.checks || []).map(row).join("");
  body.innerHTML = `
    ${head}
    ${readinessBlock(r, state)}
    <section class="qa-section">
      <h3 class="qa-section-title">Проверки</h3>
      <table class="data-table qa-table">
        <thead>
          <tr>
            <th>Группа</th>
            <th>ID</th>
            <th>Результат</th>
            <th>мс</th>
            <th>Детали</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    </section>
  `;
}

export function renderQaError(msg) {
  const body = document.getElementById("qa-body");
  if (body) body.innerHTML = `<p class="qa-status qa-status--fail">${esc(msg)}</p>`;
}
