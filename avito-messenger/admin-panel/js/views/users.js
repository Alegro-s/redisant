import { emptyState } from "../ui/empty.js";
import { num } from "../lib/format.js";
import { openUserDrawer } from "../ui/user-drawer.js";

let filter = "";
let statusFilter = "all";

export function setUsersFilter(q) {
  filter = (q || "").trim().toLowerCase();
}

export function renderUsers(root, state, { loading, onBlock, onUnblock, onRefresh }) {
  if (loading) {
    root.innerHTML = `<div class="card table-card">${emptyState("Загрузка…")}</div>`;
    return;
  }

  const users = state.users.filter((u) => {
    if (statusFilter === "hot" && (u.risk || 0) < 45) return false;
    if (statusFilter === "blocked" && u.status !== "blocked") return false;
    if (statusFilter === "active" && u.status === "blocked") return false;
    if (!filter) return true;
    const hay = `${u.name || ""} ${u.id || ""} ${u.role || ""}`.toLowerCase();
    return hay.includes(filter);
  });

  const cards =
    users.length === 0
      ? emptyState("Нет пользователей")
      : users
          .map((u) => {
            const risk = u.risk ?? 0;
            const dots = threatDots(risk);
            const blocked = u.status === "blocked";
            return `
        <article class="lead-card lead-card--${riskBand(risk)}${blocked ? " lead-card--blocked" : ""}" data-user-id="${escapeAttr(u.id)}" tabindex="0">
          <div class="lead-card__avatar">${initials(u.name)}</div>
          <div class="lead-card__body">
            <div class="lead-card__head">
              <strong>${esc(u.name || "—")}</strong>
              <span class="lead-card__role">${esc(u.role || "")}</span>
            </div>
            <p class="lead-card__sub">@${esc(u.id)} · ${u.messagesCount ?? u.messages_count ?? 0} msg</p>
            <div class="lead-card__tags">
              <span class="tag-pill">${esc(u.channel || "caht")}</span>
              ${u.chatLinked || u.chat_linked ? `<span class="tag-pill tag-pill--lime">в чате</span>` : `<span class="tag-pill">offline</span>`}
            </div>
            <div class="lead-card__foot">
              <div class="threat-dots" title="Риск ${risk}%">${dots}</div>
              <span class="lead-card__risk">${num(risk, 0)}%</span>
            </div>
          </div>
        </article>`;
          })
          .join("");

  root.innerHTML = `
    <div class="users-workspace">
      <div class="filter-bar">
        <button type="button" class="filter-chip${statusFilter === "all" ? " filter-chip--on" : ""}" data-filter="all">Все</button>
        <button type="button" class="filter-chip${statusFilter === "hot" ? " filter-chip--on" : ""}" data-filter="hot">High risk</button>
        <button type="button" class="filter-chip${statusFilter === "active" ? " filter-chip--on" : ""}" data-filter="active">Активные</button>
        <button type="button" class="filter-chip${statusFilter === "blocked" ? " filter-chip--on" : ""}" data-filter="blocked">Заблокированы</button>
        <div class="search-field search-field--grow">
          <input type="search" id="users-search" placeholder="Поиск…" value="${escapeAttr(filter)}" />
        </div>
      </div>
      <div class="lead-grid">${cards}</div>
    </div>
  `;

  root.querySelector("#users-search")?.addEventListener("input", (e) => {
    setUsersFilter(e.target.value);
    renderUsers(root, state, { loading: false, onBlock, onUnblock, onRefresh });
  });

  root.querySelectorAll("[data-filter]").forEach((btn) => {
    btn.addEventListener("click", () => {
      statusFilter = btn.dataset.filter;
      renderUsers(root, state, { loading: false, onBlock, onUnblock, onRefresh });
    });
  });

  const open = (id) => {
    const u = state.users.find((x) => x.id === id);
    if (u) openUserDrawer(u, { onBlock, onUnblock, onRefresh });
  };

  root.querySelectorAll(".lead-card").forEach((card) => {
    card.addEventListener("click", () => open(card.dataset.userId));
    card.addEventListener("keydown", (e) => {
      if (e.key === "Enter" || e.key === " ") {
        e.preventDefault();
        open(card.dataset.userId);
      }
    });
  });
}

function riskBand(r) {
  if (r >= 70) return "critical";
  if (r >= 45) return "high";
  if (r >= 25) return "mid";
  return "low";
}

function threatDots(risk) {
  const filled = risk >= 70 ? 5 : risk >= 45 ? 4 : risk >= 25 ? 3 : risk >= 10 ? 2 : 1;
  return Array.from({ length: 5 }, (_, i) => `<i class="${i < filled ? "on" : ""}"></i>`).join("");
}

function initials(name) {
  const p = String(name || "?").trim().split(/\s+/);
  return ((p[0]?.[0] || "") + (p[1]?.[0] || "")).toUpperCase() || "?";
}

function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function escapeAttr(s) {
  return esc(s).replace(/"/g, "&quot;");
}
