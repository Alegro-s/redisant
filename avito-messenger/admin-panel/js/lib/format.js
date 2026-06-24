export function num(n, digits = 0) {
  const v = Number(n);
  if (!Number.isFinite(v)) return "—";
  return v.toLocaleString("ru-RU", {
    maximumFractionDigits: digits,
    minimumFractionDigits: digits,
  });
}

export function pct(n) {
  const v = Math.min(100, Math.max(0, Number(n) || 0));
  return `${v}%`;
}

export function bytes(n) {
  const v = Number(n);
  if (!Number.isFinite(v) || v < 0) return "—";
  if (v < 1024) return `${v} B`;
  if (v < 1048576) return `${(v / 1024).toFixed(1)} KB`;
  if (v < 1073741824) return `${(v / 1048576).toFixed(1)} MB`;
  return `${(v / 1073741824).toFixed(2)} GB`;
}

export function uptime(sec) {
  const s = Number(sec);
  if (!Number.isFinite(s) || s < 0) return "—";
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (h > 0) return `${h}ч ${m}м`;
  if (m > 0) return `${m}м`;
  return `${Math.floor(s)}с`;
}

export function ms(n) {
  const v = Number(n);
  if (!Number.isFinite(v)) return "—";
  return `${num(v)} мс`;
}

export function online(svc) {
  return svc && svc.online === true;
}
