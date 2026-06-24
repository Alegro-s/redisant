import { config } from "../config.js";
import { setState } from "../core/state.js";
import { apiFetch } from "./fetch.js";

function pick(obj, keys, fallback) {
  if (!obj || typeof obj !== "object") return fallback;
  const out = { ...fallback };
  for (const k of keys) {
    if (obj[k] != null) out[k] = obj[k];
  }
  return out;
}

function mapService(raw) {
  return {
    online: !!(raw && (raw.online ?? raw.up)),
    latencyMs: raw?.latency_ms ?? raw?.latencyMs ?? null,
    uptimeSec: raw?.uptime_sec ?? raw?.uptimeSec ?? null,
    mode: raw?.mode ?? null,
    usersLinked: raw?.users_linked ?? raw?.usersLinked ?? null,
    usersTotal: raw?.users_total ?? raw?.usersTotal ?? null,
  };
}

function mapServices(raw) {
  const d = {
    messenger: { online: false, latencyMs: null, uptimeSec: null },
    gateway: { online: false, latencyMs: null, uptimeSec: null },
    core: { online: false, latencyMs: null, uptimeSec: null },
    database: { online: false, latencyMs: null, uptimeSec: null },
    explain: { online: false, latencyMs: null, uptimeSec: null },
  };
  if (!raw || typeof raw !== "object") return d;
  if (typeof raw.messenger === "boolean") {
    return {
      messenger: { online: raw.messenger, latencyMs: null, uptimeSec: null },
      gateway: { online: !!raw.gateway, latencyMs: null, uptimeSec: null },
      core: { online: !!raw.core, latencyMs: null, uptimeSec: null },
      database: { online: !!(raw.database ?? raw.postgres), latencyMs: null, uptimeSec: null },
      explain: { online: !!(raw.explain ?? raw.ollama), latencyMs: null, uptimeSec: null },
    };
  }
  return {
    messenger: mapService(raw.messenger),
    gateway: mapService(raw.gateway),
    core: mapService(raw.core),
    database: mapService(raw.database ?? raw.postgres),
    explain: mapService(raw.explain ?? raw.ollama),
    lmStudio: {
      online: !!(raw.lm_studio?.online ?? raw.lmStudio?.online),
      latencyMs: raw.lm_studio?.latency_ms ?? raw.lmStudio?.latencyMs ?? null,
      configured: !!(raw.lm_studio?.configured ?? raw.lmStudio?.configured),
      host: raw.lm_studio?.host ?? raw.lmStudio?.host ?? "",
      model: raw.lm_studio?.model ?? raw.lmStudio?.model ?? "",
      uptimeSec: raw.lm_studio?.uptime_sec ?? null,
    },
  };
}

function mapTopology(raw) {
  if (!raw || typeof raw !== "object") {
    return { mode: "local_only", fallback: "detection_v1", nodes: [], edges: [], ai: {} };
  }
  return {
    mode: raw.mode || "local_only",
    fallback: raw.fallback || "detection_v1",
    nodes: Array.isArray(raw.nodes) ? raw.nodes : [],
    edges: Array.isArray(raw.edges) ? raw.edges : [],
    ai: raw.ai || {},
  };
}
function mapProtection(raw) {
  if (!raw || typeof raw !== "object") {
    return { overallPct: 0, coreOnline: false, layers: [] };
  }
  const layers = Array.isArray(raw.layers)
    ? raw.layers.map((l) => ({
        id: l.id,
        label: l.label,
        hits24h: l.hits_24h ?? l.hits24h ?? 0,
        sharePct: l.share_pct ?? l.sharePct ?? 0,
        activePct: l.active_pct ?? l.activePct ?? 0,
        healthPct: l.health_pct ?? l.healthPct ?? 0,
      }))
    : [];
  return {
    overallPct: raw.overall_pct ?? raw.overallPct ?? 0,
    coreOnline: !!(raw.core_online ?? raw.coreOnline),
    infraPct: raw.infra_pct ?? raw.infraPct ?? 0,
    layers,
  };
}

export async function runSystemTest() {
  if (!config.apiUrl) return { ok: false, reason: "no-api" };
  try {
    const res = await apiFetch("/api/system/test", { timeoutMs: 90000 });
    if (!res.ok) return { ok: false, reason: "http", status: res.status };
    const data = await res.json();
    return { ok: true, data };
  } catch {
    return { ok: false, reason: "network" };
  }
}

export async function pullDashboard() {
  if (!config.apiUrl) return { ok: false, reason: "no-api" };
  try {
    const res = await apiFetch("/api/dashboard");
    if (!res.ok) return { ok: false, reason: "http", status: res.status };
    const data = await res.json();

    const load = pick(data.load, ["cpu", "ram", "gpu", "disk", "queue", "latency_ms", "latencyMs"], {
      cpu: 0,
      ram: 0,
      gpu: 0,
      disk: 0,
      queue: 0,
      latencyMs: 0,
    });
    if (load.latency_ms != null) load.latencyMs = load.latency_ms;

    const trafficRaw = data.traffic ?? {};
    const securityRaw = data.security ?? {};
    const detectionRaw = data.detection ?? {};
    const tokensRaw = data.tokens ?? {};

    setState({
      meta: {
        serverTime: data.meta?.server_time ?? data.meta?.serverTime ?? data.server_time ?? null,
        uptimeSec: data.meta?.uptime_sec ?? data.meta?.uptimeSec ?? data.uptime_sec ?? 0,
        version: data.meta?.version ?? data.version ?? "",
      },
      load: {
        cpu: load.cpu ?? 0,
        ram: load.ram ?? 0,
        gpu: load.gpu ?? 0,
        disk: load.disk ?? 0,
        queue: load.queue ?? 0,
        latencyMs: load.latencyMs ?? load.latency_ms ?? 0,
      },
      traffic: {
        messagesTotal: trafficRaw.messages_total ?? trafficRaw.messagesTotal ?? 0,
        messagesPerMin: trafficRaw.messages_per_min ?? trafficRaw.messagesPerMin ?? 0,
        analysesPending: trafficRaw.analyses_pending ?? trafficRaw.analysesPending ?? 0,
        analyses24h: trafficRaw.analyses_24h ?? trafficRaw.analyses24h ?? 0,
        bytesIn24h: trafficRaw.bytes_in_24h ?? trafficRaw.bytesIn24h ?? 0,
      },
      security: {
        alertsOpen: securityRaw.alerts_open ?? securityRaw.alertsOpen ?? 0,
        alertsCritical: securityRaw.alerts_critical ?? securityRaw.alertsCritical ?? 0,
        blocksActive: securityRaw.blocks_active ?? securityRaw.blocksActive ?? 0,
        usersTotal: securityRaw.users_total ?? securityRaw.usersTotal ?? 0,
        usersBlocked: securityRaw.users_blocked ?? securityRaw.usersBlocked ?? 0,
        usersHighRisk: securityRaw.users_high_risk ?? securityRaw.usersHighRisk ?? 0,
      },
      detection: {
        l1Hits24h: detectionRaw.l1_hits_24h ?? detectionRaw.l1Hits24h ?? 0,
        l2Hits24h: detectionRaw.l2_hits_24h ?? detectionRaw.l2Hits24h ?? 0,
        l3Hits24h: detectionRaw.l3_hits_24h ?? detectionRaw.l3Hits24h ?? 0,
        l4Hits24h: detectionRaw.l4_hits_24h ?? detectionRaw.l4Hits24h ?? 0,
        l5Hits24h: detectionRaw.l5_hits_24h ?? detectionRaw.l5Hits24h ?? 0,
        avgScore24h: detectionRaw.avg_score_24h ?? detectionRaw.avgScore24h ?? 0,
      },
      tokens: {
        stylometry: tokensRaw.stylometry ?? 0,
        embeddings: tokensRaw.embeddings ?? 0,
        explain: tokensRaw.explain ?? tokensRaw.xai ?? 0,
        speech: tokensRaw.speech ?? tokensRaw.whisper ?? 0,
        vision: tokensRaw.vision ?? 0,
      },
      services: mapServices(data.services),
      users: Array.isArray(data.users) ? data.users : [],
      alerts: Array.isArray(data.alerts) ? data.alerts : [],
      journal: Array.isArray(data.journal) ? data.journal : [],
      protection: mapProtection(data.protection),
      topology: mapTopology(data.topology),
    });
    return { ok: true };
  } catch {
    return { ok: false, reason: "network" };
  }
}

export async function blockUser(userId, reason) {
  if (!config.apiUrl) throw new Error("API не настроен");
  const res = await apiFetch(`/api/users/${encodeURIComponent(userId)}/block`, {
    method: "POST",
    body: JSON.stringify({ reason }),
  });
  if (!res.ok) throw new Error("Блокировка не удалась");
}

export async function unblockUser(userId) {
  if (!config.apiUrl) throw new Error("API не настроен");
  const res = await apiFetch(`/api/users/${encodeURIComponent(userId)}/unblock`, {
    method: "POST",
  });
  if (!res.ok) throw new Error("Разблокировка не удалась");
}

async function lmFetch(path, options = {}) {
  if (!config.apiUrl) return { ok: false, error: "API не настроен" };
  try {
    const res = await apiFetch(path, options);
    const data = await res.json().catch(() => ({}));
    if (!res.ok) return { ok: false, error: data.detail || `HTTP ${res.status}` };
    return { ok: true, data };
  } catch (e) {
    return { ok: false, error: e.message || "network" };
  }
}

export function fetchLmStatus() {
  return lmFetch("/api/lm-studio/status");
}

export function fetchLmModels() {
  return lmFetch("/api/lm-studio/models");
}

export function fetchLmChat(message, system = null) {
  return lmFetch("/api/lm-studio/chat", {
    method: "POST",
    body: JSON.stringify({ message, system }),
  });
}

export function fetchLmAnalyze({ text, username, force_lm }) {
  return lmFetch("/api/lm-studio/analyze", {
    method: "POST",
    body: JSON.stringify({ text, username, force_lm }),
  });
}

export function fetchShadowCampaigns() {
  return lmFetch("/api/shadow-mentor/campaigns");
}

export function createShadowCampaign(target, impersonate, autoSend = false) {
  return lmFetch("/api/shadow-mentor/campaigns", {
    method: "POST",
    body: JSON.stringify({
      target_username: target,
      impersonate_username: impersonate,
      auto_send: autoSend,
    }),
  });
}

export function sendShadowCampaign(id) {
  return lmFetch(`/api/shadow-mentor/campaigns/${id}/send`, { method: "POST" });
}

export function evaluateShadowCampaign(id, responseText) {
  return lmFetch(`/api/shadow-mentor/campaigns/${id}/evaluate`, {
    method: "POST",
    body: JSON.stringify({ response_text: responseText }),
  });
}

export function setupTelegramWebhook(publicBaseUrl) {
  return lmFetch("/webhooks/telegram/bot/setup-webhook", {
    method: "POST",
    body: JSON.stringify({ public_base_url: publicBaseUrl }),
  });
}
