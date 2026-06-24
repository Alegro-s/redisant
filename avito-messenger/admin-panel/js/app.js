import { config, getSessionToken } from "./config.js";
import { getState, subscribe } from "./core/state.js";
import { captureScroll, restoreScroll } from "./core/scroll.js";
import { pullDashboard, runSystemTest } from "./api/client.js";
import { closeQaModal, openQaModal, renderQaError, renderQaLoading, renderQaResult } from "./ui/qa-modal.js";
import { renderOverview } from "./views/overview.js";
import { renderUsers } from "./views/users.js";
import { renderAlerts } from "./views/alerts.js";
import { renderJournal } from "./views/journal.js";
import { renderAiTest } from "./views/ai-test.js";
import { renderShadowMentor } from "./views/shadow-mentor.js";
import { loadNotificationsView, bindNotificationsActions } from "./views/notifications.js";
import { runCommand, execBlock, execUnblock } from "./commands/registry.js";
import { toast } from "./ui/toast.js";
import { online } from "./lib/format.js";
import { initAuthGate, logoutAdmin } from "./auth/gate.js";
import { showLoader, hideLoader, setLoaderProgress } from "./ui/loader.js";
import { initTheme, initSidebar } from "./ui/theme.js";
import { initUserDrawer } from "./ui/user-drawer.js";

const NAV_ICONS = {
  overview: "◉",
  "ai-test": "◎",
  "shadow-mentor": "◇",
  users: "○",
  alerts: "△",
  notifications: "□",
  journal: "▤",
};

const views = {
  overview: { title: "Обзор", el: () => document.getElementById("view-overview") },
  "ai-test": { title: "Тест ИИ", el: () => document.getElementById("view-ai-test") },
  "shadow-mentor": { title: "Shadow Mentor", el: () => document.getElementById("view-shadow-mentor") },
  users: { title: "Пользователи", el: () => document.getElementById("view-users") },
  alerts: { title: "Алерты", el: () => document.getElementById("view-alerts") },
  journal: { title: "Журнал", el: () => document.getElementById("view-journal") },
  notifications: { title: "Уведомления", el: () => document.getElementById("view-notifications") },
};

const connMap = [
  ["conn-messenger", "messenger"],
  ["conn-gateway", "gateway"],
  ["conn-core", "core"],
  ["conn-db", "database"],
];

let currentView = "overview";
let loading = true;
let blockTarget = null;
let firstLoad = true;
let dashboardReady = false;
let retryTimer = null;
let appStarted = false;

function openAlertsCount() {
  const s = getState();
  if (s.security?.alertsOpen > 0) return s.security.alertsOpen;
  return s.alerts.filter((a) => a.status !== "closed").length;
}

function buildBottomNav(updateOnly = false) {
  const nav = document.getElementById("bottom-nav");
  if (!nav) return;
  const count = openAlertsCount();
  const items = [
    { id: "overview", label: "Обзор", icon: NAV_ICONS.overview },
    { id: "users", label: "Юзеры", icon: NAV_ICONS.users },
    { id: "alerts", label: "Алерты", icon: NAV_ICONS.alerts, badge: count },
    { id: "journal", label: "Журнал", icon: NAV_ICONS.journal },
    { id: "ai-test", label: "ИИ", icon: NAV_ICONS["ai-test"] },
  ];
  if (updateOnly && nav.children.length) {
    nav.querySelectorAll(".bottom-nav__item").forEach((btn) => {
      btn.classList.toggle("bottom-nav__item--active", btn.dataset.nav === currentView);
    });
    return;
  }
  nav.innerHTML = items
    .map(
      (item) => `
    <button type="button" class="bottom-nav__item${currentView === item.id ? " bottom-nav__item--active" : ""}" data-nav="${item.id}">
      <span class="bottom-nav__icon">${item.icon}</span>
      <span>${item.label}${item.badge > 0 ? ` (${item.badge})` : ""}</span>
    </button>`
    )
    .join("");
  nav.querySelectorAll("[data-nav]").forEach((btn) => {
    btn.addEventListener("click", () => navigate(btn.dataset.nav));
  });
}

function buildNav(updateOnly = false) {
  const nav = document.getElementById("sidebar-nav");
  if (!nav) return;

  const count = openAlertsCount();
  if (updateOnly && nav.querySelector("[data-nav]")) {
    nav.querySelectorAll(".nav-badge").forEach((b) => {
      if (count > 0) {
        b.textContent = String(count);
        b.removeAttribute("data-zero");
      } else {
        b.textContent = "";
        b.setAttribute("data-zero", "1");
      }
    });
    nav.querySelectorAll("[data-nav]").forEach((btn) => {
      btn.classList.toggle("nav-item--active", btn.dataset.nav === currentView);
    });
    buildBottomNav(true);
    return;
  }

  const items = [
    { id: "overview", label: "Обзор" },
    { id: "ai-test", label: "Тест ИИ" },
    { id: "shadow-mentor", label: "Shadow" },
    { id: "users", label: "Пользователи" },
    { id: "alerts", label: "Алерты", badge: true },
    { id: "notifications", label: "Уведомления" },
    { id: "journal", label: "Журнал" },
  ];
  nav.innerHTML = items
    .map((item) => {
      const badge =
        item.badge && count > 0
          ? `<span class="nav-badge">${count}</span>`
          : `<span class="nav-badge" data-zero="1"></span>`;
      const icon = NAV_ICONS[item.id] || "·";
      return `
        <button type="button" class="nav-item${currentView === item.id ? " nav-item--active" : ""}" data-nav="${item.id}">
          <span class="nav-item__icon">${icon}</span>
          <span>${item.label}</span>
          ${item.badge ? badge : ""}
        </button>`;
    })
    .join("");

  nav.querySelectorAll("[data-nav]").forEach((btn) => {
    btn.addEventListener("click", () => navigate(btn.dataset.nav));
  });
}

function updateConn() {
  const services = getState().services;
  connMap.forEach(([id, key]) => {
    const el = document.getElementById(id);
    if (!el) return;
    el.classList.toggle("status-pill--on", dashboardReady && online(services[key]));
    el.classList.toggle("status-pill--pending", !dashboardReady);
  });
}

function updateWorkspaceMeta() {
  const meta = document.getElementById("workspace-meta");
  const s = getState();
  if (!meta || !s.meta) return;
  meta.innerHTML = `
    <span class="meta-pill">${s.security?.alertsOpen || 0} алертов</span>
    <span class="meta-pill">${s.traffic?.messagesPerMin?.toFixed?.(1) || s.traffic?.messagesPerMin || 0} msg/min</span>
  `;
}

function navigate(id) {
  if (!views[id]) return;
  currentView = id;
  document.querySelectorAll(".view").forEach((v) => {
    v.classList.toggle("view--active", v.dataset.view === id);
  });
  document.getElementById("view-title").textContent = views[id].title;
  buildNav();
  if (id === "notifications") {
    paintNotifications();
  } else {
    paint(false);
  }
}

async function paintNotifications() {
  const el = views.notifications.el();
  if (!el) return;
  showLoader("Загрузка уведомлений...");
  try {
    el.innerHTML = await loadNotificationsView();
    bindNotificationsActions(el);
  } finally {
    hideLoader();
  }
}

function paint(activeOnly = false) {
  const state = getState();
  const opts = {
    loading,
    dashboardReady,
    onBlock: openBlockModal,
    onUnblock: (id) => execUnblock(id, commandCtx),
  };
  if (!activeOnly || currentView === "overview") renderOverview(views.overview.el(), state, opts);
  if (!activeOnly || currentView === "users")
    renderUsers(views.users.el(), state, {
      ...opts,
      onRefresh: () => refresh(false),
    });
  if (!activeOnly || currentView === "alerts") renderAlerts(views.alerts.el(), state, opts);
  if (!activeOnly || currentView === "journal") renderJournal(views.journal.el(), state, opts);
  if (!activeOnly || currentView === "ai-test") renderAiTest(views["ai-test"].el(), state, opts);
  if (!activeOnly || currentView === "shadow-mentor") renderShadowMentor(views["shadow-mentor"].el(), state);
  updateConn();
  updateWorkspaceMeta();
  buildNav(true);
}

function scheduleDashboardRetry(silent) {
  if (retryTimer) return;
  retryTimer = setTimeout(() => {
    retryTimer = null;
    refresh(silent);
  }, 3000);
}

async function refresh(silent = false) {
  if (!config.adminKey || !config.sessionToken) return;
  const scroll = silent ? captureScroll() : null;
  if (!silent) {
    if (firstLoad) {
      loading = true;
      showLoader();
    } else {
      setLoaderProgress(12, "Обновление данных...");
    }
  }
  const result = await pullDashboard();
  if (!silent) setLoaderProgress(72, "Обработка метрик...");
  if (!result.ok) {
    if (result.status === 401) {
      hideLoader();
      toast("Сессия истекла — войдите снова");
      logoutAdmin();
      return;
    }
    if (firstLoad) {
      hideLoader();
      if (!config.adminKey) {
        toast(`Откройте панель с ключом: ${config.adminEntryHint}`);
        logoutAdmin();
        return;
      }
      if (!silent) {
        if (result.reason === "no-api") {
          toast("Не удалось определить адрес API");
        } else if (result.reason === "network") {
          toast("Сервер не отвечает — повтор через 3 с…");
        } else {
          toast(`Ошибка API${result.status ? ` (${result.status})` : ""} — повтор…`);
        }
      }
      loading = false;
      paint(silent);
      scheduleDashboardRetry(silent);
      return;
    }
    if (!silent) hideLoader();
    if (scroll) restoreScroll(scroll);
    return;
  }
  dashboardReady = true;
  loading = false;
  firstLoad = false;
  paint(silent);
  if (!silent) hideLoader();
  if (scroll) restoreScroll(scroll);
}

function openBlockModal(userId, name) {
  blockTarget = userId;
  document.getElementById("modal-block-user").textContent = name || userId;
  document.getElementById("modal-block-reason").value = "";
  document.getElementById("modal-block").showModal();
}

function logCommand(text) {
  const log = document.getElementById("command-log");
  const line = document.createElement("div");
  line.className = "command-line";
  line.textContent = `› ${text}`;
  log.prepend(line);
  while (log.children.length > 6) log.lastChild.remove();
}

const commandCtx = {
  log: logCommand,
  toast,
  navigate,
  refresh: () => refresh(false),
  blockPrompt: (id, reason) => {
    if (reason) execBlock(id, reason, commandCtx);
    else openBlockModal(id, id);
  },
  unblock: (id) => execUnblock(id, commandCtx),
};

async function runQa() {
  openQaModal();
  renderQaLoading();
  showLoader("Контроль системы...");
  const result = await runSystemTest();
  hideLoader();
  if (!result.ok) {
    renderQaError(result.reason === "no-api" ? "Нет связи с API" : "Ошибка запроса");
    return;
  }
  renderQaResult(result.data, getState());
}

function bindUi() {
  document.getElementById("btn-qa")?.addEventListener("click", runQa);
  document.getElementById("qa-close")?.addEventListener("click", closeQaModal);
  document.getElementById("btn-refresh")?.addEventListener("click", () => refresh(false));
  document.getElementById("btn-logout")?.addEventListener("click", logoutAdmin);

  document.getElementById("command-form")?.addEventListener("submit", (e) => {
    e.preventDefault();
    const input = document.getElementById("command-input");
    const line = input.value;
    input.value = "";
    runCommand(line, commandCtx);
  });

  document.getElementById("modal-cancel")?.addEventListener("click", () => {
    document.getElementById("modal-block").close();
  });

  document.getElementById("form-block")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const reason = document.getElementById("modal-block-reason").value.trim();
    const id = blockTarget;
    document.getElementById("modal-block").close();
    if (id && reason) await execBlock(id, reason, commandCtx);
  });

  const tick = () => {
    document.getElementById("clock").textContent = new Date().toLocaleTimeString("ru-RU", {
      hour: "2-digit",
      minute: "2-digit",
    });
  };
  tick();
  setInterval(tick, 30_000);
}

function startApp() {
  if (appStarted) return;
  appStarted = true;
  initTheme();
  initSidebar();
  initUserDrawer();
  buildNav();
  bindUi();
  refresh(false);
  setInterval(() => refresh(true), config.pollMs);
}

subscribe(() => {
  if (!loading && !firstLoad) paint(true);
});

initAuthGate();
window.addEventListener("nt-auth-ok", startApp);
if (getSessionToken() && config.adminKey) {
  startApp();
}
