import { config, setAdminKey, setSessionToken, getSessionToken } from "../config.js";
import { adminHeaders } from "../api/fetch.js";

const gate = () => document.getElementById("login-gate");
const app = () => document.getElementById("app");

function showError(msg) {
  const el = document.getElementById("login-error");
  if (el) {
    el.textContent = msg;
    el.hidden = false;
  }
}

function clearError() {
  const el = document.getElementById("login-error");
  if (el) el.hidden = true;
}

async function authFetch(path, options = {}) {
  const headers = adminHeaders(options.headers || {});
  if (options.body && !headers["Content-Type"]) headers["Content-Type"] = "application/json";
  const res = await fetch(`${config.apiUrl}${path}`, { ...options, headers });
  return res;
}

function unlockApp(session) {
  setSessionToken(session);
  gate()?.classList.add("login-gate--hidden");
  app()?.classList.remove("app--locked");
  window.dispatchEvent(new CustomEvent("nt-auth-ok"));
}

function switchTab(tabId) {
  document.querySelectorAll("[data-login-tab]").forEach((btn) => {
    btn.classList.toggle("login-tab--active", btn.dataset.loginTab === tabId);
  });
  document.querySelectorAll("[data-login-panel]").forEach((panel) => {
    panel.hidden = panel.dataset.loginPanel !== tabId;
  });
  clearError();
  if (tabId === "qr" && window.ntStartQr) window.ntStartQr();
}

function requireKey() {
  const key = (config.adminKey || window.ntGetAdminKey?.() || "").trim();
  if (!key) return null;
  setAdminKey(key);
  return key;
}

function showNoKey() {
  window.ntApplyKeyUi?.();
}

function showLoginForms() {
  window.ntApplyKeyUi?.();
}

async function loginPassword(e) {
  e.preventDefault();
  if (!requireKey()) {
    showNoKey();
    return;
  }
  const user = document.getElementById("login-user")?.value?.trim();
  const pass = document.getElementById("login-pass")?.value || "";
  const res = await authFetch("/api/admin/auth/login", {
    method: "POST",
    body: JSON.stringify({ username: user, password: pass }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    showError(err.detail || "Неверный логин или пароль");
    return;
  }
  const data = await res.json();
  unlockApp(data.session);
}

function bindLoginUi() {
  const gateEl = document.getElementById("login-gate");
  if (!gateEl || gateEl.dataset.moduleBound === "1") return;
  gateEl.dataset.moduleBound = "1";
  document.getElementById("login-form")?.addEventListener("submit", loginPassword);
}

export function initAuthGate() {
  const keyFromUrl = new URLSearchParams(window.location.search).get("key")
    || new URLSearchParams(window.location.search).get("adminKey");
  if (keyFromUrl) setAdminKey(keyFromUrl);
  window.ntApplyKeyUi?.();

  if (getSessionToken() && config.adminKey) {
    gate()?.classList.add("login-gate--hidden");
    app()?.classList.remove("app--locked");
    return;
  }

  app()?.classList.add("app--locked");
  gate()?.classList.remove("login-gate--hidden");

  if (!config.adminKey && !window.ntGetAdminKey?.()) {
    showNoKey();
    return;
  }

  showLoginForms();
  bindLoginUi();
}

export function logoutAdmin() {
  setSessionToken("");
  gate()?.classList.remove("login-gate--hidden");
  app()?.classList.add("app--locked");
  if (!config.adminKey && !window.ntGetAdminKey?.()) showNoKey();
  else showLoginForms();
}
