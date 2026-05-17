(() => {
  const chat = document.getElementById("chat");
  const input = document.getElementById("input");
  const btnSend = document.getElementById("btnSend");
  const btnReset = document.getElementById("btnReset");
  const btnResetUi = document.getElementById("btnResetUi");
  const btnBannerClose = document.getElementById("btnBannerClose");
  const banner = document.getElementById("banner");
  const bannerText = document.getElementById("bannerText");
  const agentMode = document.getElementById("agentMode");
  const mainTitle = document.getElementById("mainTitle");
  const ledWs = document.getElementById("ledWs");
  const ledLlm = document.getElementById("ledLlm");

  const LS_AGENT = "roza_agent";
  const LS_TAB = "roza_tab";
  const LS_SESS = "roza_ai_sessions_v1";
  const LS_LAT = "roza_latency_ms_v1";

  let pendingLatencyTs = 0;
  /** @type {Record<string, unknown> | null} */
  let lastHealth = null;

  let uiConfig = {
    assistant_name: "Roza",
    assistant_think_first: false,
    assistant_swarm_prompt: false,
    ui_defaults: { agent: true },
  };

  /** @type {HTMLElement | null} */
  let thinkingRowEl = null;

  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  const wsUrl = `${proto}//${location.host}/ws/chat`;
  let socket = null;
  let reconnectTimer = null;
  let healthTimer = null;

  let busy = false;

  function getStore() {
    try {
      const o = JSON.parse(localStorage.getItem(LS_SESS) || "{}");
      if (!Array.isArray(o.sessions)) o.sessions = [];
      if (typeof o.currentId !== "string") o.currentId = null;
      return o;
    } catch {
      return { sessions: [], currentId: null };
    }
  }

  function putStore(o) {
    localStorage.setItem(LS_SESS, JSON.stringify(o));
  }

  function createSession() {
    const id = `${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
    return {
      id,
      title: "Новый чат",
      updated: Date.now(),
      messages: /** @type {{role:string,text:string,cls:string}[]} */ ([]),
    };
  }

  function ensureSession() {
    const st = getStore();
    if (!st.currentId || !st.sessions.find((s) => s.id === st.currentId)) {
      const s = createSession();
      st.sessions.unshift(s);
      st.currentId = s.id;
      putStore(st);
    }
    return st;
  }

  function currentSession() {
    const st = getStore();
    return st.sessions.find((s) => s.id === st.currentId) || null;
  }

  function persistMessage(role, text, cls) {
    ensureSession();
    const st = getStore();
    const s = st.sessions.find((x) => x.id === st.currentId);
    if (!s) return;
    s.messages.push({ role, text, cls });
    s.updated = Date.now();
    if (role === "Вы" && s.title === "Новый чат") {
      const t = String(text).trim().slice(0, 48);
      if (t) s.title = t + (String(text).length > 48 ? "…" : "");
    }
    putStore(st);
    renderSessionList();
  }

  function clearCurrentSessionMessages() {
    const s = currentSession();
    if (!s) return;
    s.messages = [];
    s.updated = Date.now();
    putStore(getStore());
    renderSessionList();
  }

  function renderSessionList() {
    const ul = document.getElementById("sessionList");
    if (!ul) return;
    const st = getStore();
    ul.innerHTML = "";
    const sorted = [...st.sessions].sort((a, b) => b.updated - a.updated);
    sorted.forEach((s) => {
      const li = document.createElement("li");
      li.className = "session-item" + (s.id === st.currentId ? " session-item-active" : "");
      li.textContent = s.title || "Чат";
      li.title = new Date(s.updated).toLocaleString();
      li.addEventListener("click", () => selectSession(s.id));
      ul.appendChild(li);
    });
  }

  function selectSession(id) {
    const st = getStore();
    if (!st.sessions.find((s) => s.id === id)) return;
    st.currentId = id;
    putStore(st);
    renderChatFromStore();
    renderSessionList();
    removeThinkingRow();
    if (socket && socket.readyState === WebSocket.OPEN) {
      socket.send(
        JSON.stringify({ type: "reset", session_id: getStore().currentId || "default" }),
      );
    }
  }

  function renderChatFromStore() {
    if (!chat) return;
    chat.innerHTML = "";
    const s = currentSession();
    if (!s || !s.messages.length) return;
    for (const m of s.messages) {
      addMsg(m.role, m.text, m.cls, false);
    }
    chat.scrollTop = chat.scrollHeight;
  }

  function loadLatencies() {
    try {
      const arr = JSON.parse(localStorage.getItem(LS_LAT) || "[]");
      return Array.isArray(arr) ? arr.filter((n) => typeof n === "number" && n >= 0 && n < 600000) : [];
    } catch {
      return [];
    }
  }

  function pushLatency(ms) {
    const arr = loadLatencies();
    arr.push(ms);
    localStorage.setItem(LS_LAT, JSON.stringify(arr.slice(-40)));
    drawLatencyChart();
  }

  function drawLatencyChart() {
    const c = /** @type {HTMLCanvasElement | null} */ (document.getElementById("latencyCanvas"));
    if (!c) return;
    const ctx = c.getContext("2d");
    if (!ctx) return;
    const w = c.width;
    const h = c.height;
    ctx.clearRect(0, 0, w, h);
    const data = loadLatencies().slice(-24);
    if (!data.length) {
      ctx.fillStyle = "#aeaeb2";
      ctx.font = "11px system-ui,sans-serif";
      ctx.fillText("Нет данных — отправьте сообщение", 10, 44);
      return;
    }
    const max = Math.max(...data, 100);
    const n = data.length;
    const barW = Math.max(4, (w - 20) / n - 2);
    data.forEach((v, i) => {
      const bh = Math.min(h - 18, (v / max) * (h - 22));
      const x = 10 + i * ((w - 20) / n);
      const y = h - 8 - bh;
      ctx.fillStyle = "rgba(10,132,255,0.55)";
      ctx.fillRect(x, y, barW, bh);
    });
    ctx.fillStyle = "#86868b";
    ctx.font = "10px system-ui,sans-serif";
    ctx.fillText(`последн.: ${data[data.length - 1]} мс`, 10, 12);
  }

  function renderHealthDetail() {
    const el = document.getElementById("healthDetail");
    if (!el || !lastHealth) {
      if (el) el.textContent = "Нет данных о LLM.";
      return;
    }
    const h = lastHealth;
    const b = h.llm_backend || "?";
    const ok = h.ok ? "да" : "нет";
    const parts = [`<strong>Бэкенд</strong>: <code>${b}</code>`, `<strong>Доступен</strong>: ${ok}`];
    if (b === "ollama" && h.ollama != null) parts.push(`Ollama: <code>${h.ollama}</code>`);
    if (b === "openai_compatible" && h.openai != null) parts.push(`API: <code>${h.openai}</code>`);
    if (h.model_id) parts.push(`Модель: <code>${h.model_id}</code>`);
    if (b === "hf_local") {
      if (h.preset_light) parts.push(`Пресет лёгкий: <code>${h.preset_light}</code>`);
      if (h.preset_strong) parts.push(`Пресет усиленный: <code>${h.preset_strong}</code>`);
    }
    if (h.hint) parts.push(String(h.hint));
    el.innerHTML = parts.join("<br/>");
  }

  function refreshBrainFlags() {
    const ul = document.getElementById("brainFlags");
    if (!ul) return;
    ul.innerHTML = "";
    const rows = [
      ["Двухфазное рассуждение (think_first)", !!uiConfig.assistant_think_first],
      ["Промпт «рой» (swarm_prompt)", !!uiConfig.assistant_swarm_prompt],
      ["Режим агента (инструменты)", !!agentMode.checked],
    ];
    rows.forEach(([label, on]) => {
      const li = document.createElement("li");
      li.className = "brain-li" + (on ? " brain-on" : "");
      li.textContent = `${label}: ${on ? "вкл" : "выкл"}`;
      ul.appendChild(li);
    });
  }

  function readBoolLS(key, fallback) {
    const v = localStorage.getItem(key);
    if (v === null) return fallback;
    return v === "1";
  }

  function writeBoolLS(key, val) {
    localStorage.setItem(key, val ? "1" : "0");
  }

  function applyUiDefaultsFromServer() {
    const d = uiConfig.ui_defaults || {};
    agentMode.checked = readBoolLS(LS_AGENT, d.agent !== false);
  }

  function persistToggles() {
    writeBoolLS(LS_AGENT, agentMode.checked);
  }

  let wsRelPath = ".";

  function wsJoinDir(dir, name) {
    if (!dir || dir === ".") return name;
    return `${String(dir).replace(/\\/g, "/")}/${name}`.replace(/\/+/g, "/");
  }

  function wsParentPath(p) {
    const t = String(p).replace(/\\/g, "/").replace(/\/+$/, "") || ".";
    if (t === ".") return ".";
    const i = t.lastIndexOf("/");
    return i <= 0 ? "." : t.slice(0, i) || ".";
  }

  async function refreshWorkspacePanel() {
    const hintEl = document.getElementById("workspaceCloudHint");
    const rootsUl = document.getElementById("workspaceRootsList");
    const entriesUl = document.getElementById("wsEntriesList");
    const pathEl = document.getElementById("wsBrowsePath");
    const preview = document.getElementById("wsFilePreview");
    if (!rootsUl || !entriesUl || !pathEl) return;

    try {
      const r = await fetch("/api/workspace");
      const d = await r.json();
      if (hintEl) {
        hintEl.textContent =
          d.local_only === true
            ? "Локально: диалог и workspace не уходят в облако Roza. Загрузка модели HF — по настройкам."
            : "";
      }
      rootsUl.innerHTML = "";
      (d.roots || []).forEach((root) => {
        const li = document.createElement("li");
        li.textContent = root;
        rootsUl.appendChild(li);
      });
      if (!(d.roots || []).length) {
        const li = document.createElement("li");
        li.textContent = "(нет корней — задайте workspace.roots в config.yaml)";
        rootsUl.appendChild(li);
      }
    } catch (e) {
      if (hintEl) hintEl.textContent = "Не удалось загрузить workspace.";
    }

    pathEl.textContent = wsRelPath;
    if (preview) {
      preview.hidden = true;
      preview.textContent = "";
    }
    entriesUl.innerHTML = "";

    try {
      const r2 = await fetch(`/api/workspace/list?path=${encodeURIComponent(wsRelPath)}`);
      const d2 = await r2.json();
      if (!r2.ok) {
        const msg = typeof d2.detail === "string" ? d2.detail : r2.statusText;
        throw new Error(msg || String(r2.status));
      }
      (d2.entries || []).forEach((ent) => {
        const li = document.createElement("li");
        const k = document.createElement("span");
        k.className = "ws-kind";
        k.textContent = ent.type === "dir" ? "DIR" : "файл";
        const nm = document.createElement("span");
        nm.textContent = ent.name;
        li.appendChild(k);
        li.appendChild(nm);
        li.addEventListener("click", async () => {
          const full = wsJoinDir(wsRelPath, ent.path);
          if (ent.type === "dir") {
            wsRelPath = full;
            refreshWorkspacePanel();
          } else if (preview) {
            pathEl.textContent = full;
            preview.hidden = false;
            preview.textContent = "Загрузка…";
            try {
              const rf = await fetch(`/api/workspace/file?path=${encodeURIComponent(full)}`);
              const fd = await rf.json();
              if (!rf.ok) {
                const msg = typeof fd.detail === "string" ? fd.detail : rf.statusText;
                throw new Error(msg || String(rf.status));
              }
              preview.textContent = fd.text || "";
            } catch (err) {
              preview.textContent = String(err.message || err);
            }
          }
        });
        entriesUl.appendChild(li);
      });
    } catch (e) {
      const li = document.createElement("li");
      li.textContent = String(e.message || e);
      entriesUl.appendChild(li);
    }
  }

  const MODULE_TITLES = { chat: "Чат", studio: "Студия", settings: "Настройки" };

  function setModule(id) {
    if (!["chat", "studio", "settings"].includes(id)) id = "chat";
    document.querySelectorAll(".module-pane").forEach((p) => {
      const on = p.id === `module-${id}`;
      p.classList.toggle("active", on);
      if (on) p.removeAttribute("hidden");
      else p.setAttribute("hidden", "");
    });
    document.querySelectorAll(".side-nav-item").forEach((t) => {
      const on = t.dataset.module === id;
      t.classList.toggle("active", on);
      t.setAttribute("aria-current", on ? "page" : "false");
    });
    if (mainTitle) mainTitle.textContent = MODULE_TITLES[id] || "Roza";
    localStorage.setItem(LS_TAB, id);
    if (id === "settings") refreshWorkspacePanel();
  }

  function switchToChat() {
    setModule("chat");
  }

  function showBanner(msg) {
    if (!msg) return;
    bannerText.textContent = msg;
    banner.removeAttribute("hidden");
  }

  function hideBanner() {
    banner.setAttribute("hidden", "");
  }

  function shouldBannerForError(text) {
    const s = String(text).toLowerCase();
    return (
      s.includes("503") ||
      s.includes("ollama") ||
      s.includes("занят") ||
      s.includes("недоступ") ||
      s.includes("hugging face") ||
      s.includes("загрузить hf")
    );
  }

  async function loadUiConfig() {
    try {
      const r = await fetch("/api/ui-config");
      if (r.ok) uiConfig = { ...uiConfig, ...(await r.json()) };
    } catch (e) {
      /* offline */
    }
  }

  async function pollHealth() {
    try {
      const r = await fetch("/api/health");
      if (!r.ok) throw new Error("health");
      const h = await r.json();
      lastHealth = h;
      renderHealthDetail();
      ledLlm.classList.remove("ok", "bad", "warn");
      const b = h.llm_backend || "";
      if (h.ok) {
        ledLlm.classList.add("ok");
        if (b === "ollama") ledLlm.title = "Ollama: доступна";
        else if (b === "llama_cpp") ledLlm.title = "LLM: llama.cpp (GGUF)";
        else if (b === "openai_compatible") ledLlm.title = "LLM: OpenAI-совместимый API";
        else if (b === "hf_local") ledLlm.title = `HF локально: ${h.model_id || "модель"}`;
        else ledLlm.title = `LLM: ${b}`;
      } else {
        ledLlm.classList.add(b === "ollama" ? "warn" : "bad");
        if (b === "ollama") {
          ledLlm.title =
            h.ollama === "down" ? "Ollama: нет соединения" : `Ollama: ${h.status_code ?? "ошибка"}`;
        } else if (b === "llama_cpp") {
          ledLlm.title = "llama.cpp: нет файла модели (llama_cpp.model_path)";
        } else if (b === "openai_compatible") {
          ledLlm.title = "API недоступен (openai_compatible.base_url)";
        } else if (b === "hf_local") {
          ledLlm.title = h.hint || "HF: установите .[hf] и проверьте model_id";
        } else ledLlm.title = "LLM недоступен";
      }
    } catch (e) {
      lastHealth = null;
      renderHealthDetail();
      ledLlm.classList.remove("ok", "warn");
      ledLlm.classList.add("bad");
      ledLlm.title = "Проверка LLM недоступна";
    }
    await refreshLearningPanel();
  }

  let suppressLearningToggle = false;

  async function refreshLearningPanel() {
    const row = document.getElementById("llmPresetRow");
    const ind = document.getElementById("learningIndicator");
    const cap = document.getElementById("learningStatusText");
    const pre = document.getElementById("learningStatsDetail");
    const toggle = document.getElementById("learningToggle");
    if (!row || !ind || !cap || !pre || !toggle) return;

    if (lastHealth && lastHealth.llm_backend === "hf_local") row.removeAttribute("hidden");
    else row.setAttribute("hidden", "");

    try {
      const r = await fetch("/api/learning/stats");
      if (!r.ok) throw new Error("stats");
      const st = await r.json();
      cap.textContent = `${st.enabled ? "Журнал: запись вкл" : "Журнал: запись выкл"} · в config: ${st.persisted_in_config ? "да" : "нет"}`;
      ind.classList.toggle("on", !!st.enabled);
      pre.textContent = `Строк: ${st.lines}\n≈ ${(st.bytes / 1024).toFixed(1)} КБ\n${st.log_path}`;
      suppressLearningToggle = true;
      toggle.checked = !!st.enabled;
      suppressLearningToggle = false;
    } catch (e) {
      cap.textContent = "Нет данных /api/learning/stats";
      ind.classList.remove("on");
      pre.textContent = "";
    }
  }
    if (thinkingRowEl && thinkingRowEl.parentNode) {
      thinkingRowEl.parentNode.removeChild(thinkingRowEl);
    }
    thinkingRowEl = null;
  }

  function showThinkingRow() {
    removeThinkingRow();
    const div = document.createElement("div");
    div.className = "msg bot msg-thinking";
    div.setAttribute("aria-live", "polite");
    div.setAttribute("aria-busy", "true");
    const r = document.createElement("div");
    r.className = "role";
    r.textContent = "Roza";
    const wrap = document.createElement("div");
    wrap.className = "thinking-wrap";
    const lab = document.createElement("span");
    lab.className = "thinking-label";
    lab.textContent = "Думаю…";
    const dots = document.createElement("span");
    dots.className = "typing-dots";
    for (let i = 0; i < 3; i += 1) {
      dots.appendChild(document.createElement("span"));
    }
    wrap.appendChild(lab);
    wrap.appendChild(dots);
    div.appendChild(r);
    div.appendChild(wrap);
    chat.appendChild(div);
    thinkingRowEl = div;
    chat.scrollTop = chat.scrollHeight;
  }

  function addMsg(role, text, cls, doPersist = true) {
    const div = document.createElement("div");
    div.className = `msg ${cls}`;
    const r = document.createElement("div");
    r.className = "role";
    r.textContent = role;
    const t = document.createElement("div");
    t.className = "msg-body";
    t.textContent = text;
    div.appendChild(r);
    div.appendChild(t);
    chat.appendChild(div);
    chat.scrollTop = chat.scrollHeight;
    if (doPersist) persistMessage(role, text, cls);
  }

  function addBotReplyAnimated(fullText, onDone) {
    removeThinkingRow();
    const plain = String(fullText);
    const div = document.createElement("div");
    div.className = "msg bot msg-typing-out";
    const r = document.createElement("div");
    r.className = "role";
    r.textContent = "Roza";
    const t = document.createElement("div");
    t.className = "msg-body is-typing";
    t.textContent = "";
    div.appendChild(r);
    div.appendChild(t);
    chat.appendChild(div);
    chat.scrollTop = chat.scrollHeight;

    if (plain.length > 4500) {
      t.textContent = plain;
      t.classList.remove("is-typing");
      div.classList.remove("msg-typing-out");
      if (onDone) onDone();
      return;
    }

    let i = 0;
    const step = () => {
      const chunk = Math.min(14, 2 + Math.ceil(plain.length / 400));
      i = Math.min(plain.length, i + chunk);
      t.textContent = plain.slice(0, i);
      chat.scrollTop = chat.scrollHeight;
      if (i < plain.length) {
        const delay = plain.length > 2400 ? 6 : plain.length > 800 ? 10 : 14;
        setTimeout(step, delay);
      } else {
        t.classList.remove("is-typing");
        div.classList.remove("msg-typing-out");
        if (onDone) onDone();
      }
    };
    step();
  }

  function connect() {
    if (socket && socket.readyState === WebSocket.OPEN) return;
    socket = new WebSocket(wsUrl);

    socket.onopen = () => {
      ledWs.classList.remove("bad", "warn");
      ledWs.classList.add("ok");
      ledWs.title = "Связь с сервером: есть";
      clearTimeout(reconnectTimer);
    };

    socket.onmessage = (ev) => {
      const data = JSON.parse(ev.data);
      if (data.type === "thinking") {
        if (!thinkingRowEl) showThinkingRow();
        switchToChat();
        return;
      }
      if (data.type === "reply") {
        switchToChat();
        addBotReplyAnimated(data.text, () => {
          busy = false;
          persistMessage("Roza", data.text, "bot");
          if (data.usage && typeof data.usage === "object") {
            const u = data.usage;
            const line = `Токены: prompt ${u.prompt_tokens ?? "?"} · completion ${u.completion_tokens ?? "?"} · всего ${u.total_tokens ?? "?"}`;
            addMsg("Токены", line, "meta");
            persistMessage("Токены", line, "meta");
          }
          if (pendingLatencyTs) {
            pushLatency(Math.round(performance.now() - pendingLatencyTs));
            pendingLatencyTs = 0;
          }
        });
        pollHealth();
        return;
      }
      if (data.type === "error") {
        busy = false;
        removeThinkingRow();
        addMsg("Ошибка", data.message, "error");
        switchToChat();
        if (shouldBannerForError(data.message)) showBanner(data.message);
        pollHealth();
        return;
      }
      if (data.type === "reset_ok") {
        removeThinkingRow();
        addMsg("Система", "Сессия сброшена.", "bot");
      }
    };

    socket.onclose = () => {
      ledWs.classList.remove("ok", "warn");
      ledWs.classList.add("bad");
      ledWs.title = "Нет связи. Запустите: python -m roza desktop";
      reconnectTimer = setTimeout(connect, 2800);
    };

    socket.onerror = () => socket.close();
  }

  function sendText(text) {
    const t = text.trim();
    if (!t || !socket || socket.readyState !== WebSocket.OPEN || busy) return;
    busy = true;
    pendingLatencyTs = performance.now();
    switchToChat();
    addMsg("Вы", t, "user");
    showThinkingRow();
    socket.send(
      JSON.stringify({
        type: "message",
        text: t,
        agent: agentMode.checked,
        session_id: getStore().currentId || "default",
      }),
    );
  }

  btnSend.addEventListener("click", () => {
    const t = input.value.trim();
    if (t) {
      input.value = "";
      sendText(t);
    }
  });

  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      btnSend.click();
    }
  });

  btnReset.addEventListener("click", () => {
    if (socket && socket.readyState === WebSocket.OPEN) {
      socket.send(
        JSON.stringify({ type: "reset", session_id: getStore().currentId || "default" }),
      );
    }
    removeThinkingRow();
    chat.innerHTML = "";
    clearCurrentSessionMessages();
    hideBanner();
  });

  btnBannerClose.addEventListener("click", hideBanner);

  btnResetUi.addEventListener("click", () => {
    localStorage.removeItem(LS_AGENT);
    localStorage.removeItem(LS_TAB);
    applyUiDefaultsFromServer();
    setModule("settings");
    refreshBrainFlags();
  });

  agentMode.addEventListener("change", () => {
    persistToggles();
    refreshBrainFlags();
  });

  const btnWsUp = document.getElementById("btnWsUp");
  const btnWsRefresh = document.getElementById("btnWsRefresh");
  if (btnWsUp) {
    btnWsUp.addEventListener("click", () => {
      wsRelPath = wsParentPath(wsRelPath);
      refreshWorkspacePanel();
    });
  }
  if (btnWsRefresh) {
    btnWsRefresh.addEventListener("click", () => refreshWorkspacePanel());
  }

  const learningToggle = document.getElementById("learningToggle");
  if (learningToggle) {
    learningToggle.addEventListener("change", async () => {
      if (suppressLearningToggle) return;
      try {
        const r = await fetch("/api/learning/enabled", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ enabled: learningToggle.checked }),
        });
        if (!r.ok) throw new Error("bad");
        await refreshLearningPanel();
      } catch (e) {
        suppressLearningToggle = true;
        learningToggle.checked = !learningToggle.checked;
        suppressLearningToggle = false;
      }
    });
  }

  document.querySelectorAll(".btn-preset").forEach((btn) => {
    btn.addEventListener("click", async () => {
      const preset = btn.getAttribute("data-preset") || "default";
      try {
        const r = await fetch("/api/llm/preset", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ preset }),
        });
        if (!r.ok) {
          let msg = r.statusText;
          try {
            const d = await r.json();
            if (d && d.detail) msg = typeof d.detail === "string" ? d.detail : JSON.stringify(d.detail);
          } catch (e2) {
            /* ignore */
          }
          showBanner(msg);
          return;
        }
        await pollHealth();
      } catch (e) {
        showBanner(String(e.message || e));
      }
    });
  });

  const datasetFile = document.getElementById("datasetFile");
  const btnDatasetPick = document.getElementById("btnDatasetPick");
  if (btnDatasetPick && datasetFile) {
    btnDatasetPick.addEventListener("click", () => datasetFile.click());
    datasetFile.addEventListener("change", async () => {
      if (!datasetFile.files || !datasetFile.files[0]) return;
      const fd = new FormData();
      fd.append("file", datasetFile.files[0]);
      try {
        const r = await fetch("/api/studio/datasets/upload", { method: "POST", body: fd });
        const d = await r.json().catch(() => ({}));
        if (!r.ok) {
          const msg = typeof d.detail === "string" ? d.detail : r.statusText;
          showBanner(msg || "Ошибка загрузки");
        }
        await pollHealth();
      } catch (e) {
        showBanner(String(e.message || e));
      } finally {
        datasetFile.value = "";
      }
    });
  }

  document.querySelectorAll(".side-nav-item").forEach((btn) => {
    btn.addEventListener("click", () => setModule(btn.dataset.module || "chat"));
  });

  const btnNewChat = document.getElementById("btnNewChat");
  if (btnNewChat) {
    btnNewChat.addEventListener("click", () => {
      const st = getStore();
      const cur = currentSession();
      if (cur && cur.messages.length === 0) return;
      const s = createSession();
      st.sessions.unshift(s);
      st.currentId = s.id;
      putStore(st);
      chat.innerHTML = "";
      removeThinkingRow();
      if (socket && socket.readyState === WebSocket.OPEN) {
        socket.send(
          JSON.stringify({ type: "reset", session_id: getStore().currentId || "default" }),
        );
      }
      renderSessionList();
      setModule("chat");
    });
  }

  loadUiConfig().then(() => {
    applyUiDefaultsFromServer();
    ensureSession();
    renderSessionList();
    renderChatFromStore();
    const tab = localStorage.getItem(LS_TAB);
    if (tab && ["chat", "studio", "settings"].includes(tab)) setModule(tab);
    else setModule("chat");
    connect();
    pollHealth();
    healthTimer = setInterval(pollHealth, 8000);
    refreshBrainFlags();
    drawLatencyChart();
  });
})();
