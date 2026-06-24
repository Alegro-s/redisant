const defaults = {
  meta: { serverTime: null, uptimeSec: 0, version: "" },
  load: { cpu: 0, ram: 0, gpu: 0, disk: 0, queue: 0, latencyMs: 0 },
  traffic: {
    messagesTotal: 0,
    messagesPerMin: 0,
    analysesPending: 0,
    analyses24h: 0,
    bytesIn24h: 0,
  },
  security: {
    alertsOpen: 0,
    alertsCritical: 0,
    blocksActive: 0,
    usersTotal: 0,
    usersBlocked: 0,
    usersHighRisk: 0,
  },
  detection: {
    l1Hits24h: 0,
    l2Hits24h: 0,
    l3Hits24h: 0,
    l4Hits24h: 0,
    l5Hits24h: 0,
    avgScore24h: 0,
  },
  tokens: {
    stylometry: 0,
    embeddings: 0,
    explain: 0,
    speech: 0,
    vision: 0,
  },
  services: {
    messenger: { online: false, latencyMs: null, uptimeSec: null },
    gateway: { online: false, latencyMs: null, uptimeSec: null },
    core: { online: false, latencyMs: null, uptimeSec: null },
    database: { online: false, latencyMs: null, uptimeSec: null },
    explain: { online: false, latencyMs: null, uptimeSec: null },
    lmStudio: { online: false, latencyMs: null, configured: false, host: "", model: "" },
  },
  users: [],
  alerts: [],
  journal: [],
  protection: {
    overallPct: 0,
    coreOnline: false,
    layers: [],
  },
  topology: { mode: "local_only", fallback: "detection_v1", nodes: [], edges: [], ai: {} },
};

const empty = () => JSON.parse(JSON.stringify(defaults));

let snapshot = empty();
const listeners = new Set();

export function getState() {
  return snapshot;
}

export function setState(patch) {
  snapshot = { ...snapshot, ...patch };
  listeners.forEach((fn) => fn(snapshot));
}

export function resetState() {
  snapshot = empty();
  listeners.forEach((fn) => fn(snapshot));
}

export function subscribe(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}
