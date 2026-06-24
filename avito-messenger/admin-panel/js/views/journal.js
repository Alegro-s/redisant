import { emptyState } from "../ui/empty.js";

export function renderJournal(root, state, { loading }) {
  if (loading) {
    root.innerHTML = `<div class="card">${emptyState("Загрузка…")}</div>`;
    return;
  }

  const lines = state.journal;
  const content =
    lines.length === 0
      ? emptyState("Журнал пуст")
      : `<div class="log-scroll">${lines
          .map(
            (e) =>
              `<div class="log-line"><time>${esc(e.time || "")}</time><span class="log-type">${esc(e.type || e.level || "")}</span> ${esc(e.text || e.message || "")}</div>`
          )
          .join("")}</div>`;

  root.innerHTML = `<div class="card card--flat">${content}</div>`;
}

function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}
