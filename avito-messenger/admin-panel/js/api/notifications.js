import { apiFetch } from "./fetch.js";

export async function fetchNotificationsStatus() {
  return apiFetch("/api/notifications/status");
}

export async function fetchNotificationSubscribers() {
  return apiFetch("/api/notifications/subscribers");
}

export async function testOpsTelegram() {
  return apiFetch("/api/notifications/test/ops-chat", { method: "POST" });
}

export async function testUserTelegram(username) {
  return apiFetch("/api/notifications/test/user", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username, title: "Тест Neural Trust", body: "Личное уведомление из админ-панели." }),
  });
}

export async function setupTelegramWebhook(publicBaseUrl) {
  return apiFetch("/api/notifications/telegram/webhook", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ public_base_url: publicBaseUrl }),
  });
}
