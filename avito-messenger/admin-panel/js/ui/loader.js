const STAGES = [
  { at: 8, text: "Подключение к API..." },
  { at: 28, text: "Загрузка метрик хоста..." },
  { at: 52, text: "Синхронизация детекции L1–L6..." },
  { at: 78, text: "Построение топологии..." },
  { at: 94, text: "Проверка готовности..." },
];

let visible = false;
let progress = 0;
let timer = null;

function el(id) {
  return document.getElementById(id);
}

function stageText(p) {
  let t = STAGES[0].text;
  for (const s of STAGES) {
    if (p >= s.at) t = s.text;
  }
  return t;
}

function paint() {
  const fill = el("loader-fill");
  const label = el("loader-label");
  const pct = el("loader-pct");
  if (fill) fill.style.width = `${progress}%`;
  if (label) label.textContent = stageText(progress);
  if (pct) pct.textContent = `${Math.round(progress)}%`;
}

export function showLoader(message) {
  const root = el("sys-loader");
  if (!root) return;
  visible = true;
  progress = 0;
  root.classList.add("sys-loader--visible");
  if (message && el("loader-label")) el("loader-label").textContent = message;
  paint();
  if (timer) clearInterval(timer);
  timer = setInterval(() => {
    if (!visible) return;
    if (progress < 88) {
      progress += Math.random() * 6 + 2;
      progress = Math.min(88, progress);
      paint();
    }
  }, 280);
}

export function setLoaderProgress(value, message) {
  progress = Math.min(100, Math.max(0, value));
  if (message && el("loader-label")) el("loader-label").textContent = message;
  paint();
}

export function hideLoader() {
  const root = el("sys-loader");
  if (!root) return;
  progress = 100;
  paint();
  setTimeout(() => {
    visible = false;
    if (timer) clearInterval(timer);
    timer = null;
    root.classList.remove("sys-loader--visible");
    progress = 0;
    paint();
  }, 320);
}

export function isLoaderVisible() {
  return visible;
}
