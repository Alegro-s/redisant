import { emptyState } from "../ui/empty.js";
import { num } from "../lib/format.js";

function levelChip(level) {
  const map = { critical: "chip--critical", high: "chip--high", medium: "chip--risk", low: "chip--ok" };
  return map[level] || "chip--ok";
}

export function renderAlerts(root, state, { loading }) {
  if (loading) {
    root.innerHTML = `<div class="card table-card">${emptyState("Загрузка…")}</div>`;
    return;
  }

  const alerts = state.alerts;
  const body =
    alerts.length === 0
      ? emptyState("Нет алертов")
      : `
    <table class="data-table">
      <thead>
        <tr>
          <th>Время</th>
          <th>Уровень</th>
          <th>Score</th>
          <th>Пользователь</th>
          <th>Канал</th>
          <th>Правило</th>
          <th>Сигнал</th>
          <th>Статус</th>
        </tr>
      </thead>
      <tbody>
        ${alerts
          .map(
            (a) => `
          <tr>
            <td>${esc(a.time || "—")}</td>
            <td><span class="chip ${levelChip(a.level)}">${esc(a.level || "—")}</span></td>
            <td>${a.score != null ? num(a.score, 1) : "—"}</td>
            <td>${esc(a.user || a.userId || "—")}</td>
            <td>${esc(a.channel || "—")}</td>
            <td>${esc(a.rule || a.layer || "—")}</td>
            <td>${esc(a.signal || a.title || "—")}</td>
            <td>${esc(a.status || "open")}</td>
          </tr>`
          )
          .join("")}
      </tbody>
    </table>`;

  root.innerHTML = `<div class="card table-card">${body}</div>`;
}

function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}
