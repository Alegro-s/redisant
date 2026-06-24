const KEY = "nt_skin";

export const SKINS = [
  { id: "classic", label: "Классика (бело-синяя)", theme: "light", skin: "classic" },
  { id: "workspace-light", label: "Workspace светлая", theme: "light", skin: "workspace" },
  { id: "workspace-dark", label: "Workspace тёмная", theme: "dark", skin: "workspace" },
];

export function initTheme() {
  const saved = localStorage.getItem(KEY) || "workspace-dark";
  const skin = SKINS.find((s) => s.id === saved) || SKINS[2];
  applySkin(skin.id);

  document.getElementById("btn-theme")?.addEventListener("click", openThemeModal);
  document.getElementById("theme-modal-close")?.addEventListener("click", closeThemeModal);
  document.getElementById("theme-modal-backdrop")?.addEventListener("click", closeThemeModal);

  const grid = document.getElementById("theme-skin-grid");
  if (grid) {
    grid.innerHTML = SKINS.map(
      (s) => `
      <button type="button" class="skin-option" data-skin-id="${s.id}">
        <span class="skin-option__preview skin-option__preview--${s.id}"></span>
        <span class="skin-option__label">${s.label}</span>
      </button>`
    ).join("");
    grid.querySelectorAll("[data-skin-id]").forEach((btn) => {
      btn.addEventListener("click", () => {
        applySkin(btn.dataset.skinId);
        closeThemeModal();
      });
    });
  }
}

function applySkin(id) {
  const skin = SKINS.find((s) => s.id === id) || SKINS[2];
  const root = document.documentElement;
  root.setAttribute("data-theme", skin.theme);
  root.setAttribute("data-skin", skin.skin);
  root.dataset.skinId = skin.id;
  localStorage.setItem(KEY, skin.id);

  const btn = document.getElementById("btn-theme");
  if (btn) btn.textContent = "Оформление";

  document.querySelectorAll(".skin-option").forEach((el) => {
    el.classList.toggle("skin-option--active", el.dataset.skinId === skin.id);
  });
}

function openThemeModal() {
  const m = document.getElementById("theme-modal");
  if (!m) return;
  const cur = localStorage.getItem(KEY) || "workspace-dark";
  document.querySelectorAll(".skin-option").forEach((el) => {
    el.classList.toggle("skin-option--active", el.dataset.skinId === cur);
  });
  m.classList.add("theme-modal--open");
  m.setAttribute("aria-hidden", "false");
}

function closeThemeModal() {
  const m = document.getElementById("theme-modal");
  m?.classList.remove("theme-modal--open");
  m?.setAttribute("aria-hidden", "true");
}

function syncSidebarToggle(aside, btn) {
  if (!aside || !btn) return;
  const collapsed = aside.classList.contains("sidebar--collapsed");
  btn.textContent = collapsed ? "›" : "‹";
  btn.title = collapsed ? "Развернуть меню" : "Свернуть меню";
}

export function initSidebar() {
  const aside = document.getElementById("sidebar");
  const btn = document.getElementById("btn-sidebar-toggle");
  const saved = localStorage.getItem("nt_sidebar_collapsed") === "1";
  if (saved && aside) aside.classList.add("sidebar--collapsed");
  syncSidebarToggle(aside, btn);
  btn?.addEventListener("click", () => {
    aside?.classList.toggle("sidebar--collapsed");
    localStorage.setItem("nt_sidebar_collapsed", aside?.classList.contains("sidebar--collapsed") ? "1" : "0");
    syncSidebarToggle(aside, btn);
  });
}
