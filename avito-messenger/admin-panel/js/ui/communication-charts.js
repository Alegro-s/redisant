function esc(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

export function communicationGraph(data) {
  const points = data?.points || [];
  const w = 320;
  const h = 112;
  const pad = { t: 10, r: 8, b: 18, l: 8 };
  const innerW = w - pad.l - pad.r;
  const innerH = h - pad.t - pad.b;

  if (!points.length) {
    return `
      <div class="comm-graph comm-graph--empty">
        <p class="muted">Недостаточно сообщений для графика</p>
      </div>`;
  }

  const vals = points.map((p) => Number(p.value) || 0);
  const baselines = points.map((p) => Number(p.baseline) || 0);
  const max = 100;
  const min = 0;
  const range = max - min || 1;
  const step = innerW / Math.max(points.length - 1, 1);

  const toY = (v) => pad.t + innerH - ((v - min) / range) * innerH;
  const toX = (i) => pad.l + i * step;

  const linePath = (arr, key) =>
    arr
      .map((p, i) => `${i === 0 ? "M" : "L"}${toX(i).toFixed(1)},${toY(Number(p[key]) || 0).toFixed(1)}`)
      .join(" ");

  const valuePath = linePath(points, "value");
  const basePath = linePath(points, "baseline");
  const areaPath = `${valuePath} L${toX(points.length - 1).toFixed(1)},${(pad.t + innerH).toFixed(1)} L${pad.l},${(pad.t + innerH).toFixed(1)} Z`;

  const spikes = points
    .map((p, i) => {
      if (!p.anomaly && !(Number(p.spike) > 8)) return "";
      const x = toX(i);
      const y = toY(Number(p.value) || 0);
      return `<circle class="comm-graph__spike" cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="3.5" data-time="${esc(p.time)}" data-risk="${p.risk ?? 0}"/>`;
    })
    .join("");

  const sustained = data?.sustained
    ? `<span class="comm-graph__badge comm-graph__badge--warn">устойчивое отклонение</span>`
    : data?.elevated_streak > 0
      ? `<span class="comm-graph__badge">всплески</span>`
      : `<span class="comm-graph__badge comm-graph__badge--ok">норма</span>`;

  return `
    <div class="comm-graph">
      <div class="comm-graph__head">
        <span class="comm-graph__title">График общения</span>
        ${sustained}
      </div>
      <p class="comm-graph__hint muted">${esc(data?.label || "")}</p>
      <svg class="comm-graph__svg" viewBox="0 0 ${w} ${h}" width="100%" height="${h}" role="img" aria-label="График общения">
        <defs>
          <linearGradient id="commGraphFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="var(--nt-lime)" stop-opacity="0.35"/>
            <stop offset="100%" stop-color="var(--nt-lime)" stop-opacity="0.02"/>
          </linearGradient>
        </defs>
        ${[0.25, 0.5, 0.75].map((g) => {
          const y = toY(g * 100);
          return `<line class="comm-graph__grid" x1="${pad.l}" y1="${y.toFixed(1)}" x2="${w - pad.r}" y2="${y.toFixed(1)}"/>`;
        }).join("")}
        <path class="comm-graph__area" d="${areaPath}" fill="url(#commGraphFill)"/>
        <path class="comm-graph__baseline" d="${basePath}" fill="none"/>
        <path class="comm-graph__line" d="${valuePath}" fill="none"/>
        ${spikes}
      </svg>
      <div class="comm-graph__legend">
        <span><i class="comm-graph__dot comm-graph__dot--line"></i>динамика</span>
        <span><i class="comm-graph__dot comm-graph__dot--base"></i>база</span>
        <span><i class="comm-graph__dot comm-graph__dot--spike"></i>аномалия</span>
      </div>
    </div>`;
}

export function styleRadar(zonesData) {
  const zones = zonesData?.zones || [];
  const n = zones.length || 6;
  const cx = 130;
  const cy = 130;
  const R = 78;
  const labelR = R + 22;

  if (!zones.length) {
    return `<div class="style-radar style-radar--empty"><p class="muted">Профиль стиля ещё обучается</p></div>`;
  }

  const angles = zones.map((_, i) => (i * 2 * Math.PI) / n - Math.PI / 2);

  const pt = (i, radius) => {
    const v = Math.max(0.08, Math.min(1, Number(zones[i].value) || 0));
    const r = radius * v;
    return [cx + Math.cos(angles[i]) * r, cy + Math.sin(angles[i]) * r];
  };

  const rings = [0.2, 0.4, 0.6, 0.8, 1.0]
    .map((level) => {
      const ring = angles
        .map((a, i) => {
          const x = cx + Math.cos(a) * R * level;
          const y = cy + Math.sin(a) * R * level;
          return `${i === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`;
        })
        .join(" ");
      return `<path class="style-radar__ring" d="${ring} Z"/>`;
    })
    .join("");

  const axes = angles
    .map((a) => {
      const x2 = cx + Math.cos(a) * R;
      const y2 = cy + Math.sin(a) * R;
      return `<line class="style-radar__axis" x1="${cx}" y1="${cy}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}"/>`;
    })
    .join("");

  const polygon = angles
    .map((_, i) => {
      const [x, y] = pt(i, R);
      return `${i === 0 ? "M" : "L"}${x.toFixed(1)},${y.toFixed(1)}`;
    })
    .join(" ");

  const labels = zones
    .map((z, i) => {
      const x = cx + Math.cos(angles[i]) * labelR;
      const y = cy + Math.sin(angles[i]) * labelR;
      const anchor = Math.abs(Math.cos(angles[i])) < 0.2 ? "middle" : Math.cos(angles[i]) > 0 ? "start" : "end";
      const pct = Math.round((Number(z.value) || 0) * 100);
      return `
        <text class="style-radar__label" x="${x.toFixed(1)}" y="${y.toFixed(1)}" text-anchor="${anchor}" dominant-baseline="middle">
          ${esc(z.label)} ${pct}%
        </text>`;
    })
    .join("");

  const vectors = zones
    .map((z, i) => {
      const [x, y] = pt(i, R);
      const color = zoneColor(i);
      return `
        <line class="style-radar__vector" x1="${cx}" y1="${cy}" x2="${x.toFixed(1)}" y2="${y.toFixed(1)}" style="stroke:${color}"/>
        <circle class="style-radar__node" cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="4" style="fill:${color}"/>`;
    })
    .join("");

  const learning = Number(zonesData?.learning_pct) || 0;

  return `
    <div class="style-radar">
      <div class="style-radar__head">
        <span class="style-radar__title">Стилистика общения</span>
        <span class="style-radar__meta muted">обучение ${learning}%</span>
      </div>
      <svg class="style-radar__svg" viewBox="0 0 260 260" width="100%" role="img" aria-label="Диаграмма стиля общения">
        ${rings}
        ${axes}
        <path class="style-radar__fill" d="${polygon} Z"/>
        ${vectors}
        ${labels}
      </svg>
      <p class="style-radar__foot muted">6 зон: длина, эмоции, вопросы, регистр, вежливость, стабильность</p>
    </div>`;
}

function zoneColor(i) {
  const colors = ["#facc15", "#ef4444", "#22c55e", "#38bdf8", "#a855f7", "#fb923c"];
  return colors[i % colors.length];
}
