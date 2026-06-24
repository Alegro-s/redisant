import { fetchUserPanel, purgeUserData, unlockMessages } from "../api/users.js";
import { toast } from "./toast.js";

let openUser = null;
let handlers = null;

export function initUserDrawer() {
  document.getElementById("user-drawer-backdrop")?.addEventListener("click", closeUserDrawer);
  document.getElementById("user-drawer-close")?.addEventListener("click", closeUserDrawer);
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeUserDrawer();
  });
}

export function openUserDrawer(user, { onBlock, onUnblock, onRefresh }) {
  openUser = user;
  handlers = { onBlock, onUnblock, onRefresh };
  const root = document.getElementById("user-drawer");
  root?.classList.add("user-drawer--open");
  root?.removeAttribute("inert");
  root?.setAttribute("aria-hidden", "false");
  document.body.classList.add("drawer-open");
  renderDrawerLoading(user);
  loadDrawer(user.id || user.name);
  requestAnimationFrame(() => document.getElementById("user-drawer-close")?.focus());
}

export function closeUserDrawer() {
  openUser = null;
  const root = document.getElementById("user-drawer");
  const active = document.activeElement;
  if (root?.contains(active) && active instanceof HTMLElement) {
    active.blur();
  }
  root?.classList.remove("user-drawer--open");
  root?.setAttribute("aria-hidden", "true");
  root?.setAttribute("inert", "");
  document.body.classList.remove("drawer-open");
}

function renderDrawerLoading(user) {
  const panel = document.getElementById("user-drawer-body");
  if (!panel) return;
  panel.innerHTML = `
    <div class="drawer-hero drawer-hero--loading">
      <div class="drawer-avatar">${initials(user.name)}</div>
      <div><h2>${esc(user.name)}</h2><p class="muted">Загрузка…</p></div>
    </div>`;
}

async function loadDrawer(username) {
  const panel = document.getElementById("user-drawer-body");
  if (!panel) return;
  try {
    const res = await fetchUserPanel(username);
    if (!res.ok) {
      const hint =
        res.status === 404
          ? "Профиль не найден (обновите API на сервере)"
          : res.reason === "network"
            ? "Сеть недоступна"
            : `Ошибка ${res.status || "—"}`;
      panel.innerHTML = `<p class="muted">${hint}</p>`;
      return;
    }
    renderDrawer(res.data);
  } catch {
    panel.innerHTML = `<p class="muted">Не удалось загрузить профиль</p>`;
  }
}

function renderDrawer(d) {
  const panel = document.getElementById("user-drawer-body");
  if (!panel) return;
  const threatClass =
    d.threat_level >= 70 ? "threat--critical" : d.threat_level >= 45 ? "threat--high" : d.threat_level >= 25 ? "threat--mid" : "threat--low";
  const blocked = d.status === "blocked";

  const msgs =
    d.recent_messages?.length > 0
      ? d.recent_messages
          .map(
            (m) => `
        <div class="drawer-msg">
          <time>${esc(m.time)}</time>
          <span class="chip chip--risk">${m.risk}%</span>
          <p>${esc(m.text)}</p>
        </div>`
          )
          .join("")
      : `<p class="muted">Нет сообщений</p>`;

  const activity =
    d.activity?.length > 0
      ? `<ul class="drawer-timeline">${d.activity
          .map(
            (a) => `
          <li><time>${esc(a.time)}</time><span>${esc(a.type)}</span><p>${esc(a.text)}</p></li>`
          )
          .join("")}</ul>`
      : `<p class="muted">Нет событий аудита</p>`;

  const unlockUi = d.messages_unlocked
    ? `<p class="muted drawer-unlock-ok">🔓 Просмотр расшифрован · ~${Math.max(1, Math.floor((d.messages_unlock_ttl || 0) / 60))} мин</p>`
    : `<div class="drawer-unlock">
        <label class="muted" for="drawer-view-key">Ключ просмотра E2E</label>
        <input type="password" id="drawer-view-key" class="drawer-unlock__input" placeholder="MSG_ADMIN_VIEW_KEY" autocomplete="off" />
        <button type="button" class="btn-tonal" id="drawer-unlock-msgs">Показать сообщения</button>
      </div>`;

  panel.innerHTML = `
    <div class="drawer-hero">
      <div class="drawer-avatar drawer-avatar--${threatClass}">${initials(d.name)}</div>
      <div class="drawer-hero__meta">
        <h2>${esc(d.name)}</h2>
        <p class="muted">@${esc(d.id)} · ${esc(d.role)}</p>
        <div class="drawer-chips">
          <span class="chip ${blocked ? "chip--block" : "chip--ok"}">${blocked ? "заблокирован" : "активен"}</span>
          ${d.voice_enrolled ? `<span class="chip chip--ok">голос enroll</span>` : ""}
        </div>
      </div>
    </div>

    <div class="drawer-threat ${threatClass}">
      <div class="drawer-threat__label">Уровень угрозы</div>
      <div class="drawer-threat__value">${d.threat_level}%</div>
      <div class="drawer-threat__sub">${esc(d.threat_label)}</div>
      <div class="drawer-threat__bar"><span style="width:${Math.min(100, d.threat_level)}%"></span></div>
    </div>

    <div class="drawer-stats">
      <div class="drawer-stat"><span>Сообщений</span><strong>${d.messages_count}</strong></div>
      <div class="drawer-stat"><span>Ср. риск ML</span><strong>${d.ml?.avg_risk ?? 0}%</strong></div>
      <div class="drawer-stat"><span>High risk</span><strong>${d.ml?.high_risk_count ?? 0}</strong></div>
      <div class="drawer-stat"><span>Активность</span><strong>${esc(d.last_seen || "—")}</strong></div>
    </div>

    <section class="drawer-section">
      <h3>Последние сообщения</h3>
      ${unlockUi}
      <div class="drawer-msgs">${msgs}</div>
    </section>

    <section class="drawer-section drawer-section--dark">
      <h3>Активность</h3>
      ${activity}
    </section>

    <div class="drawer-actions">
      ${
        blocked
          ? `<button type="button" class="btn-tonal" id="drawer-unblock">Разблокировать</button>`
          : d.can_block
            ? `<button type="button" class="btn-tonal btn-tonal--danger" id="drawer-block">Заблокировать</button>`
            : ""
      }
      ${
        d.can_block
          ? `<button type="button" class="btn-text btn-text--danger" id="drawer-purge">Удалить сообщения</button>`
          : ""
      }
    </div>
  `;

  panel.querySelector("#drawer-unlock-msgs")?.addEventListener("click", async () => {
    const key = panel.querySelector("#drawer-view-key")?.value?.trim() || "";
    if (!key) {
      toast("Введите ключ просмотра");
      return;
    }
    const r = await unlockMessages(key);
    if (!r.ok) {
      toast(r.detail || "Не удалось разблокировать");
      return;
    }
    toast(`Сообщения доступны ${Math.floor((r.data?.expires_in || 0) / 60)} мин`);
    loadDrawer(d.id);
  });

  panel.querySelector("#drawer-block")?.addEventListener("click", () => {
    closeUserDrawer();
    handlers?.onBlock?.(d.id, d.name);
  });
  panel.querySelector("#drawer-unblock")?.addEventListener("click", () => {
    closeUserDrawer();
    handlers?.onUnblock?.(d.id);
  });
  panel.querySelector("#drawer-purge")?.addEventListener("click", async () => {
    if (!confirm(`Удалить все сообщения пользователя ${d.name}?`)) return;
    const r = await purgeUserData(d.id);
    if (!r.ok) {
      toast(r.detail || "Ошибка удаления");
      return;
    }
    toast(`Удалено сообщений: ${r.data?.purged?.messages ?? 0}`);
    handlers?.onRefresh?.();
    loadDrawer(d.id);
  });
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
