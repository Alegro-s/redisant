export function sparkline(values, { w = 120, h = 36, stroke = "var(--nt-lime)" } = {}) {
  const pts = (values || []).map((v) => Number(v) || 0);
  if (!pts.length) return `<svg width="${w}" height="${h}" class="chart-spark"></svg>`;
  const max = Math.max(...pts, 1);
  const min = Math.min(...pts, 0);
  const range = max - min || 1;
  const step = w / Math.max(pts.length - 1, 1);
  const d = pts
    .map((v, i) => {
      const x = i * step;
      const y = h - 4 - ((v - min) / range) * (h - 8);
      return `${i === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");
  const area = `${d} L${w},${h} L0,${h} Z`;
  return `
    <svg width="${w}" height="${h}" class="chart-spark" viewBox="0 0 ${w} ${h}">
      <path d="${area}" fill="var(--nt-lime-glow)" opacity="0.5"/>
      <path d="${d}" fill="none" stroke="${stroke}" stroke-width="2" stroke-linecap="round"/>
    </svg>`;
}

export function miniBars(values, labels, { h = 80 } = {}) {
  const vals = (values || []).map((v) => Number(v) || 0);
  const max = Math.max(...vals, 1);
  const bars = vals
    .map((v, i) => {
      const bh = Math.max(4, (v / max) * (h - 20));
      return `<div class="mini-bar" style="height:${bh}px" title="${labels?.[i] || ""}: ${v}"></div>`;
    })
    .join("");
  const lbl = (labels || [])
    .map((l) => `<span>${l}</span>`)
    .join("");
  return `<div class="mini-bars" style="height:${h}px">${bars}</div><div class="mini-bars-labels">${lbl}</div>`;
}

export function detectionTimeline(detection) {
  const layers = [
    { id: "L1", label: "Стилометрия", val: detection.l1Hits24h, color: "var(--nt-lime)" },
    { id: "L2", label: "Семантика", val: detection.l2Hits24h, color: "#5eead4" },
    { id: "L3", label: "Метаданные", val: detection.l3Hits24h, color: "#38bdf8" },
    { id: "L4", label: "Синтетика", val: detection.l4Hits24h, color: "#a855f7" },
    { id: "L5", label: "Интент", val: detection.l5Hits24h, color: "#f472b6" },
    { id: "L6", label: "Голос", val: detection.l6Hits24h || 0, color: "#fb923c" },
  ];
  const max = Math.max(...layers.map((l) => l.val), 1);
  return `
    <div class="sys-timeline">
      <div class="sys-timeline__rail"></div>
      ${layers
        .map(
          (l, i) => `
        <div class="sys-timeline__node" style="--i:${i}">
          <div class="sys-timeline__dot" style="background:${l.color}"></div>
          <div class="sys-timeline__card">
            <div class="sys-timeline__head">
              <strong>${l.id}</strong>
              <span>${l.label}</span>
            </div>
            <div class="sys-timeline__bar">
              <div class="sys-timeline__fill" style="width:${((l.val / max) * 100).toFixed(0)}%;background:${l.color}"></div>
            </div>
            <div class="sys-timeline__val">${l.val} <span class="muted">за 24ч</span></div>
          </div>
        </div>`
        )
        .join("")}
    </div>`;
}

export function readinessGauge(percent) {
  const p = Math.min(100, Math.max(0, Number(percent) || 0));
  const r = 42;
  const c = 2 * Math.PI * r;
  const off = c - (p / 100) * c;
  return `
    <div class="readiness-gauge">
      <svg width="100" height="100" viewBox="0 0 100 100">
        <circle cx="50" cy="50" r="${r}" fill="none" stroke="var(--nt-border)" stroke-width="8"/>
        <circle cx="50" cy="50" r="${r}" fill="none" stroke="var(--nt-lime)" stroke-width="8"
          stroke-dasharray="${c}" stroke-dashoffset="${off}" stroke-linecap="round"
          transform="rotate(-90 50 50)"/>
        <text x="50" y="54" text-anchor="middle" class="readiness-gauge__text">${Math.round(p)}%</text>
      </svg>
    </div>`;
}

export function syntheticSeries(base, n = 12) {
  const b = Number(base) || 10;
  return Array.from({ length: n }, (_, i) => Math.max(0, b + Math.sin(i * 0.9) * b * 0.4 + (i % 3) * 2));
}
