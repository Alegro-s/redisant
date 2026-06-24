import {
  createShadowCampaign,
  evaluateShadowCampaign,
  fetchShadowCampaigns,
  sendShadowCampaign,
  setupTelegramWebhook,
} from "../api/client.js";
import { config } from "../config.js";
import { toast } from "../ui/toast.js";

let campaigns = [];

async function reload() {
  const res = await fetchShadowCampaigns();
  campaigns = res.ok ? res.data : [];
}

function row(c) {
  const badge =
    c.fell_for_it === true
      ? '<span class="badge badge--danger">Попался</span>'
      : c.fell_for_it === false
        ? '<span class="badge badge--ok">Бдителен</span>'
        : `<span class="badge">${c.status}</span>`;
  return `
    <tr data-id="${c.id}">
      <td>${c.target_username}</td>
      <td>${c.impersonate_username || "—"}</td>
      <td class="cell-muted">${(c.message_text || "").slice(0, 80)}…</td>
      <td>${badge}</td>
      <td>
        ${c.status === "draft" ? `<button type="button" class="btn-text" data-send="${c.id}">Отправить</button>` : ""}
        ${c.status === "sent" ? `<button type="button" class="btn-text" data-eval="${c.id}">Оценить ответ</button>` : ""}
      </td>
    </tr>`;
}

export async function renderShadowMentor(el, state) {
  if (!el) return;
  await reload();
  el.innerHTML = `
    <section class="panel">
      <h2 class="panel-title">Shadow Mentor — симуляция фишинга</h2>
      <p class="panel-sub">Персонализированное сообщение в стиле, противоположном Linguistic DNA сотрудника (бонус).</p>
      <form id="sm-form" class="form-grid">
        <label class="field"><span>Жертва</span><input name="target" placeholder="user2" required /></label>
        <label class="field"><span>Импersonация</span><input name="impersonate" placeholder="ceo" required /></label>
        <label class="field field--check"><input type="checkbox" name="auto" /> Отправить сразу в чат</label>
        <button type="submit" class="btn-filled">Создать кампанию</button>
      </form>
    </section>
    <section class="panel">
      <h3 class="panel-title">Telegram Bot</h3>
      <p class="panel-sub">Пользователи: <code>/link логин пароль</code> в боте. Webhook:</p>
      <form id="tg-webhook-form" class="form-inline">
        <input name="base" placeholder="https://72.56.244.26:8000" value="${config.apiUrl}" style="min-width:280px" />
        <button type="submit" class="btn-text">setWebhook</button>
      </form>
    </section>
    <section class="panel">
      <table class="data-table">
        <thead><tr><th>Жертва</th><th>От имени</th><th>Текст</th><th>Итог</th><th></th></tr></thead>
        <tbody>${campaigns.map(row).join("") || '<tr><td colspan="5">Нет кампаний</td></tr>'}</tbody>
      </table>
    </section>`;

  el.querySelector("#sm-form")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const fd = new FormData(e.target);
    const res = await createShadowCampaign(fd.get("target"), fd.get("impersonate"), fd.get("auto") === "on");
    if (res.ok) {
      toast("Кампания создана");
      renderShadowMentor(el, state);
    } else toast(res.error || "Ошибка");
  });

  el.querySelector("#tg-webhook-form")?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const base = new FormData(e.target).get("base");
    const res = await setupTelegramWebhook(base);
    toast(res.ok ? `Webhook: ${res.data.detail}` : res.error || "Ошибка");
  });

  el.querySelectorAll("[data-send]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const res = await sendShadowCampaign(btn.dataset.send);
      toast(res.ok ? "Отправлено" : res.error || "Ошибка");
      renderShadowMentor(el, state);
    });
  });

  el.querySelectorAll("[data-eval]").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const text = window.prompt("Ответ сотрудника на фишинг:");
      if (!text) return;
      const res = await evaluateShadowCampaign(btn.dataset.eval, text);
      if (res.ok) {
        toast(res.data.fell_for_it ? "⚠ Сотрудник попался" : "✓ Сотрудник не попался");
        renderShadowMentor(el, state);
      } else toast(res.error || "Ошибка");
    });
  });
}
