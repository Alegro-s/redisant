export function captureScroll() {
  const viewport = document.getElementById("viewport");
  const log = document.querySelector(".view--active .log-scroll");
  return {
    viewport: viewport?.scrollTop ?? 0,
    log: log?.scrollTop ?? 0,
  };
}

export function restoreScroll(saved) {
  if (!saved) return;
  const viewport = document.getElementById("viewport");
  if (viewport) viewport.scrollTop = saved.viewport;
  const log = document.querySelector(".view--active .log-scroll");
  if (log) log.scrollTop = saved.log;
}
