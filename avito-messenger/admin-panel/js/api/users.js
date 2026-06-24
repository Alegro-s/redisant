import { apiFetch } from "./fetch.js";

export async function fetchUserPanel(username) {
  try {
    const res = await apiFetch(`/api/users/${encodeURIComponent(username)}/panel`, { timeoutMs: 15000 });
    if (!res.ok) return { ok: false, status: res.status };
    return { ok: true, data: await res.json() };
  } catch {
    return { ok: false, status: 0, reason: "network" };
  }
}

export async function unlockMessages(viewKey) {
  try {
    const res = await apiFetch("/api/admin/messages/unlock", {
      method: "POST",
      body: JSON.stringify({ view_key: viewKey }),
      timeoutMs: 15000,
    });
    if (!res.ok) {
      let detail = "Неверный ключ";
      try {
        const j = await res.json();
        detail = j.detail || detail;
      } catch (_) {}
      return { ok: false, detail };
    }
    return { ok: true, data: await res.json() };
  } catch {
    return { ok: false, detail: "Сеть недоступна" };
  }
}

export async function purgeUserData(username) {
  try {
    const res = await apiFetch(`/api/users/${encodeURIComponent(username)}/data`, {
      method: "DELETE",
      timeoutMs: 20000,
    });
    if (!res.ok) {
      let detail = "Ошибка";
      try {
        const j = await res.json();
        detail = j.detail || detail;
      } catch (_) {}
      return { ok: false, detail };
    }
    return { ok: true, data: await res.json() };
  } catch {
    return { ok: false, detail: "Сеть недоступна" };
  }
}
