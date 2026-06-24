import { ms, num } from "../lib/format.js";

function esc(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

const MODE_LABELS = {
  local_only: "только локальные L1–L5",
  local_fallback: "локально (AI офлайн)",
  lm_studio_hybrid: "LM Studio + локально",
  ai_core_remote: "AI Core по сети",
};

const STATUS_RU = {
  online: "онлайн",
  offline: "офлайн",
  degraded: "деградация",
  disabled: "отключён",
};

function statusLabel(status) {
  return STATUS_RU[status] || status || "—";
}

function statusClass(status) {
  if (status === "online") return "arch-node--on";
  if (status === "degraded") return "arch-node--warn";
  if (status === "disabled") return "arch-node--off arch-node--dim";
  return "arch-node--off";
}

function nodeBox(node) {
  const lat =
    node.latency_ms != null && node.latency_ms > 0
      ? `<span class="arch-node__lat">${ms(node.latency_ms)}</span>`
      : "";
  const note = node.note ? `<span class="arch-node__note">${esc(node.note)}</span>` : "";
  const opt = node.optional ? `<span class="arch-node__tag">опц.</span>` : "";
  return `
    <div class="arch-node ${statusClass(node.status)}" data-node="${esc(node.id)}" title="${esc(node.label)}">
      <div class="arch-node__title">${esc(node.label)}${opt}</div>
      <div class="arch-node__meta"><span class="arch-node__status">${esc(statusLabel(node.status))}</span>${lat}${note}</div>
    </div>
  `;
}

function layoutNodes(nodes) {
  const byId = Object.fromEntries((nodes || []).map((n) => [n.id, n]));
  const rowMain = ["messenger", "gateway", "local_l1l5", "fusion", "postgres"]
    .filter((id) => byId[id])
    .map((id) => nodeBox(byId[id]))
    .join('<div class="arch-arrow" aria-hidden="true">→</div>');

  const lm = byId.lm_studio;
  const aiCore = byId.ai_core;
  const side = [lm, aiCore].filter(Boolean);

  const sideHtml = side.length
    ? `
      <div class="arch-side">
        ${side.map((n) => nodeBox(n)).join("")}
      </div>
    `
    : "";

  return `<div class="arch-row">${rowMain}</div>${sideHtml}`;
}

function edgeLegend(edges) {
  return (edges || [])
    .filter((e) => e.active || !e.optional)
    .slice(0, 6)
    .map((e) => {
      const cls = e.active ? "arch-legend__item--on" : "arch-legend__item--off";
      const label = e.label ? ` · ${esc(e.label)}` : "";
      return `<span class="arch-legend__item ${cls}">${esc(e.from)} → ${esc(e.to)}${label}</span>`;
    })
    .join("");
}

function aiTiming(ai) {
  const lm = ai?.lm_studio || {};
  const exp = lm.expected_ms || {};
  const rows = [
    ["L1–L5 локально", exp.local_layers || "5–80 ms"],
    ["Пинг LM Studio", exp.network_ping || "10–200 ms"],
    ["Explain (risk≥0.4)", exp.lm_explain || "0.8–4 с"],
    ["Полный LLM-разбор", exp.lm_intent || "1.5–6 с"],
  ];
  return rows
    .map(
      ([k, v]) =>
        `<div class="arch-timing-row"><span>${esc(k)}</span><span class="arch-timing-val">${esc(v)}</span></div>`
    )
    .join("");
}

export function renderTopologySection(topology, services, { dashboardReady = true } = {}) {
  if (!dashboardReady) {
    return `
      <section class="section arch-section">
        <h3>Архитектура и ИИ</h3>
        <p class="section-hint arch-section--pending">Загрузка топологии…</p>
      </section>
    `;
  }
  if (!topology || !topology.nodes?.length) {
    return `<section class="section"><h3>Архитектура</h3><p class="section-hint">Топология недоступна.</p></section>`;
  }

  const mode = MODE_LABELS[topology.mode] || topology.mode || "—";
  const lm = services?.lm_studio || {};
  const ai = topology.ai || {};
  const lmLine = lm.configured
    ? `LM Studio ${lm.host || ""}: ${lm.online ? "online" : "offline"}`
    : "LM Studio не настроен — работают локальные слои";

  return `
    <section class="section arch-section">
      <h3>Архитектура и ИИ</h3>
      <p class="section-hint">Режим: <strong>${esc(mode)}</strong> · fallback: ${esc(topology.fallback || "detection_v1")} · ${esc(lmLine)}</p>
      <div class="arch-diagram card card--flat">
        ${layoutNodes(topology.nodes)}
        <div class="arch-legend">${edgeLegend(topology.edges)}</div>
      </div>
      <div class="arch-grid-2">
        <div class="card card--flat">
          <h4 class="arch-subtitle">Ожидаемое время анализа</h4>
          ${aiTiming(ai)}
        </div>
        <div class="card card--flat">
          <h4 class="arch-subtitle">Цепочка обработки</h4>
          <ol class="arch-flow-list">
            ${(ai.analysis_flow || [])
              .map((line) => `<li>${esc(line)}</li>`)
              .join("")}
          </ol>
        </div>
      </div>
    </section>
  `;
}

export function renderTopologyCompact(topology) {
  if (!topology?.nodes?.length) return "";
  const on = topology.nodes.filter((n) => n.status === "online").length;
  const total = topology.nodes.filter((n) => !n.optional || n.status !== "disabled").length;
  const mode = MODE_LABELS[topology.mode] || topology.mode;
  return `
    <div class="arch-compact">
      <span class="arch-compact__mode">${esc(mode)}</span>
      <span class="arch-compact__stat">узлов online: ${num(on)}/${num(total)}</span>
    </div>
  `;
}
