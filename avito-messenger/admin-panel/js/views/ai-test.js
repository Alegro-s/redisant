import { fetchLmAnalyze, fetchLmChat, fetchLmStatus, fetchLmModels } from "../api/client.js";

function esc(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function statusChip(ok, label) {
  return `<span class="chip ${ok ? "chip--ok" : "chip--off"}">${label}</span>`;
}

export function renderAiTest(root, _state, { loading }) {
  if (loading) {
    root.innerHTML = `<div class="card"><div class="skeleton skeleton-block"></div></div>`;
    return;
  }

  root.innerHTML = `
    <div class="ai-test-grid">
      <section class="card section">
        <h3>Приватный шлюз вывода</h3>
        <p class="muted">Локальный узел inference на выделённом хосте (зашифрованный профиль <code>INFERENCE_PROFILE</code>).</p>
        <div id="ai-lm-status" class="ai-status-box muted">Загрузка…</div>
        <button type="button" class="btn-text" id="ai-refresh-status">Проверить снова</button>
      </section>

      <section class="card section">
        <h3>Свободный запрос к модели</h3>
        <label class="field">
          <span class="field-label">Сообщение</span>
          <textarea id="ai-chat-input" rows="4" placeholder="Например: Объясни, почему это сообщение подозрительно…"></textarea>
        </label>
        <button type="button" class="btn-filled" id="ai-chat-send">Запрос к шлюзу</button>
        <pre id="ai-chat-out" class="ai-out muted">Ответ появится здесь</pre>
      </section>

      <section class="card section ai-test-span">
        <h3>Анализ переписки (L1–L6)</h3>
        <p class="muted">Прод-пайплайн: локальные слои, fusion, серый коридор, приватный шлюз для вердикта.</p>
        <label class="field">
          <span class="field-label">Текст сообщения</span>
          <textarea id="ai-analyze-input" rows="5" placeholder="Например: Уважаемый коллега, срочно переведите 500 000 на счёт…"></textarea>
        </label>
        <label class="field">
          <span class="field-label">От чьего имени (профиль)</span>
          <input type="text" id="ai-analyze-user" value="ceo" />
        </label>
        <label class="field field--row">
          <input type="checkbox" id="ai-force-lm" checked />
          <span>Принудительный вызов шлюза (тест)</span>
        </label>
        <button type="button" class="btn-filled" id="ai-analyze-send">Проанализировать</button>
        <div id="ai-analyze-out" class="ai-analyze-result muted">Результат анализа</div>
      </section>
    </div>
  `;

  bindAiTest(root);
  loadLmStatus(root);
}

function bindAiTest(root) {
  root.querySelector("#ai-refresh-status")?.addEventListener("click", () => loadLmStatus(root));
  root.querySelector("#ai-chat-send")?.addEventListener("click", () => runChat(root));
  root.querySelector("#ai-analyze-send")?.addEventListener("click", () => runAnalyze(root));
}

async function loadLmStatus(root) {
  const box = root.querySelector("#ai-lm-status");
  if (!box) return;
  box.textContent = "Проверка…";
  const [st, models] = await Promise.all([fetchLmStatus(), fetchLmModels()]);
  if (!st.ok) {
    box.innerHTML = `<p class="muted">Шлюз недоступен${st.error ? `: ${esc(st.error)}` : ""}</p>`;
    return;
  }
  const d = st.data;
  const m = models.ok ? models.data : { models: [], error: models.error };
  box.innerHTML = `
    <div class="ai-status-lines">
      <div>${statusChip(d.online, d.online ? "Шлюз online" : "Шлюз offline")}</div>
      <div><strong>Узел:</strong> ${esc(d.host || "—")} · <strong>Задержка:</strong> ${d.latency_ms ?? "—"} ms</div>
      <div><strong>Модель:</strong> <code>${esc(d.model)}</code></div>
      <div><strong>Доступ:</strong> ${d.auth_configured ? "ключ задан" : "без ключа"} · ${esc(d.detail || "")}</div>
      <div><strong>Каталог моделей:</strong> ${m.models?.length ? esc(m.models.join(", ")) : esc(m.error || "—")}</div>
      <div class="muted">Порог вызова ИИ в проде: risk ≥ ${Math.round((d.min_risk || 0.4) * 100)}%</div>
    </div>
  `;
}

async function runChat(root) {
  const input = root.querySelector("#ai-chat-input");
  const out = root.querySelector("#ai-chat-out");
  const text = input?.value?.trim();
  if (!text) {
    out.textContent = "Введите текст запроса";
    return;
  }
  out.textContent = "Запрос…";
  const res = await fetchLmChat(text);
  if (!res.ok) {
    out.textContent = res.error || "Ошибка";
    return;
  }
  if (!res.data.ok) {
    out.textContent = res.data.error || "Шлюз не ответил";
    return;
  }
  out.textContent = `[${res.data.model}, ${res.data.inference_ms} ms]\n\n${res.data.content}`;
}

async function runAnalyze(root) {
  const text = root.querySelector("#ai-analyze-input")?.value?.trim();
  const username = root.querySelector("#ai-analyze-user")?.value?.trim() || "ceo";
  const force = root.querySelector("#ai-force-lm")?.checked ?? true;
  const out = root.querySelector("#ai-analyze-out");
  if (!text) {
    out.innerHTML = "<p>Введите текст сообщения</p>";
    return;
  }
  out.innerHTML = "<p>Анализ…</p>";
  const res = await fetchLmAnalyze({ text, username, force_lm: force });
  if (!res.ok) {
    out.innerHTML = `<p class="chip chip--off">${esc(res.error)}</p>`;
    return;
  }
  const d = res.data;
  const layers = d.layer_hits
    ? Object.entries(d.layer_hits)
        .filter(([, v]) => v)
        .map(([k]) => k)
        .join(", ")
    : "—";
  out.innerHTML = `
    <div class="ai-result-head">
      ${statusChip(d.risk_pct >= 40, `Риск ${d.risk_pct}%`)}
      <span class="chip">${esc(d.analysis_source)}</span>
    </div>
    <h4>${esc(d.title_ru)}</h4>
    <p>${esc(d.explanation_ru)}</p>
    <p class="muted"><strong>Слои:</strong> ${esc(layers)} · <strong>Тип:</strong> ${esc(d.alert_type || "—")}</p>
    <details>
      <summary>Локальный анализ (L1–L5)</summary>
      <pre class="ai-out">${esc(JSON.stringify(d.local, null, 2))}</pre>
    </details>
    <details>
      <summary>LM Studio</summary>
      <pre class="ai-out">${esc(JSON.stringify(d.lm_studio, null, 2))}</pre>
    </details>
  `;
}
