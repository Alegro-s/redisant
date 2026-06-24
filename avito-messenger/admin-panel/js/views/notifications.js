import {
  fetchNotificationsStatus,
  fetchNotificationSubscribers,
  setupTelegramWebhook,
  testOpsTelegram,
  testUserTelegram,
} from "../api/notifications.js";
import { toast } from "../ui/toast.js";
import { online } from "../lib/format.js";

let _status = null;
let _subs = [];

function publicHost() {
  return (window.NT_PUBLIC_HOST || window.NT_API_URL || "").replace(/\/$/, "");
}

export async function loadNotificationsView() {
  try {
    _status = await fetchNotificationsStatus();
    const data = await fetchNotificationSubscribers();
    _subs = data.subscribers || [];
    return buildHtml();
  } catch (e) {
    return `<div class="card card--error"><p>Не удалось загрузить: ${e.message}</p></div>`;
  }
}

function buildHtml() {
  const tg = _status?.telegram || {};
  const inf = _status?.inference || {};
  const mode = inf.mode || "—";
  const nodes = inf.nodes || {};

  const nodeRows = Object.entries(nodes)
    .map(
      ([id, n]) => `
      <tr>
        <td>${id}</td>
        <td>${online(n.online)}</td>
        <td class="muted">${n.detail || "—"}</td>
      </tr>`
    )
    .join("");

  const subRows = _subs
    .map(
      (s) => `
      <tr>
        <td><strong>${s.username}</strong></td>
        <td>${s.display_name}</td>
        <td>${s.role}</td>
        <td>${s.notify_security ? "да" : "нет"}</td>
        <td>${s.notify_messages ? "да" : "нет"}</td>
      </tr>`
    )
    .join("");

  return `
    <div class="grid grid--2">
      <section class="card">
        <h2 class="card-title">Telegram</h2>
        <dl class="kv">
          <dt>Бот</dt><dd>${tg.bot_configured ? "настроен" : "нет токена"} @${tg.bot_username || "—"}</dd>
          <dt>Ops-чат</dt><dd>${tg.ops_chat_configured ? "да" : "нет TELEGRAM_ALERT_CHAT_ID"}</dd>
          <dt>Подписчиков</dt><dd>${tg.linked_users ?? _subs.length}</dd>
        </dl>
        <div class="btn-row">
          <button type="button" class="btn-filled" id="btn-tg-ops-test">Тест ops-канала</button>
          <button type="button" class="btn-text" id="btn-tg-webhook">Webhook бота</button>
        </div>
        <p class="muted" style="margin-top:12px">Привязка из caht: меню → Уведомления → Подключить Telegram.</p>
      </section>

      <section class="card">
        <h2 class="card-title">Inference (GPU-ПК)</h2>
        <p>Режим: <strong>${mode}</strong> · online: ${inf.online_count ?? "—"}</p>
        <table class="table table--compact">
          <thead><tr><th>Узел</th><th>Статус</th><th>Детали</th></tr></thead>
          <tbody>${nodeRows || "<tr><td colspan='3'>Нет данных</td></tr>"}</tbody>
        </table>
      </section>
    </div>

    <section class="card" style="margin-top:16px">
      <h2 class="card-title">Подписчики</h2>
      <table class="table">
        <thead>
          <tr><th>Логин</th><th>Имя</th><th>Роль</th><th>Безопасность</th><th>Сообщения</th></tr>
        </thead>
        <tbody>${subRows || "<tr><td colspan='5'>Пока никто не привязал Telegram</td></tr>"}</tbody>
      </table>
      <div class="btn-row" style="margin-top:12px">
        <label class="field field--inline">
          <span class="field-label">Тест пользователю</span>
          <input type="text" id="notif-test-user" placeholder="ceo" value="ceo" />
        </label>
        <button type="button" class="btn-text" id="btn-tg-user-test">Отправить тест</button>
      </div>
    </section>

    <input type="hidden" id="notif-public-host" value="${publicHost()}" />
  `;
}

export function bindNotificationsActions(root) {
  root.querySelector("#btn-tg-ops-test")?.addEventListener("click", async () => {
    try {
      const r = await testOpsTelegram();
      toast(r.ok ? "Отправлено в ops-чат" : "Ошибка отправки");
    } catch (e) {
      toast(e.message);
    }
  });

  root.querySelector("#btn-tg-webhook")?.addEventListener("click", async () => {
    const host = root.querySelector("#notif-public-host")?.value || publicHost();
    if (!host) {
      toast("Задайте NT_API_URL");
      return;
    }
    try {
      const r = await setupTelegramWebhook(host);
      toast(r.ok ? `Webhook: ${r.webhook_url}` : "Ошибка webhook");
    } catch (e) {
      toast(e.message);
    }
  });

  root.querySelector("#btn-tg-user-test")?.addEventListener("click", async () => {
    const username = root.querySelector("#notif-test-user")?.value?.trim();
    if (!username) return;
    try {
      const r = await testUserTelegram(username);
      toast(r.ok ? `Тест @${username}` : "Не доставлено");
    } catch (e) {
      toast(e.message);
    }
  });
}
