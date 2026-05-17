(() => {
  const treeRoot = document.getElementById("treeRoot");
  const fileList = document.getElementById("fileList");
  const dropzone = document.getElementById("dropzone");
  const fileInput = document.getElementById("fileInput");
  const healthEl = document.getElementById("healthStatus");
  const logEl = document.getElementById("studioLog");
  const btnBench = document.getElementById("btnBench");
  const btnExportLearn = document.getElementById("btnExportLearn");
  const btnRefresh = document.getElementById("btnRefresh");

  const trainDepsEl = document.getElementById("trainDeps");
  const trainDataset = document.getElementById("trainDataset");
  const trainBase = document.getElementById("trainBase");
  const trainRun = document.getElementById("trainRun");
  const trainEpochs = document.getElementById("trainEpochs");
  const trainLr = document.getElementById("trainLr");
  const trainR = document.getElementById("trainR");
  const trainAlpha = document.getElementById("trainAlpha");
  const trainSeq = document.getElementById("trainSeq");
  const trainBs = document.getElementById("trainBs");
  const trainGa = document.getElementById("trainGa");
  const train4bit = document.getElementById("train4bit");
  const btnTrainStart = document.getElementById("btnTrainStart");
  const btnTrainLog = document.getElementById("btnTrainLog");
  const trainStatusEl = document.getElementById("trainStatus");
  const trainLogPre = document.getElementById("trainLogPre");

  let trainPollTimer = null;

  function log(msg) {
    logEl.textContent = `${new Date().toLocaleTimeString()} ${msg}\n${logEl.textContent}`.slice(
      0,
      4000,
    );
  }

  function statusClass(st) {
    if (st === "ok") return "ok";
    if (st === "fail") return "fail";
    return "unknown";
  }

  function renderTree(nodes) {
    treeRoot.innerHTML = "";
    if (!nodes || !nodes.length) {
      treeRoot.textContent = "Добавьте skills.yaml в корень проекта.";
      return;
    }
    const ul = document.createElement("ul");
    function walk(items, parent) {
      items.forEach((n) => {
        const li = document.createElement("li");
        const row = document.createElement("div");
        row.className = "node-row";
        const dot = document.createElement("span");
        dot.className = `status-dot ${statusClass(n.status)}`;
        dot.title = n.status || "unknown";
        const lab = document.createElement("span");
        lab.textContent = n.label || n.id || "?";
        row.appendChild(dot);
        row.appendChild(lab);
        li.appendChild(row);
        const ch = n.children;
        if (ch && ch.length) {
          const sub = document.createElement("ul");
          walk(ch, sub);
          li.appendChild(sub);
        }
        parent.appendChild(li);
      });
    }
    walk(nodes, ul);
    treeRoot.appendChild(ul);
  }

  async function loadSkills() {
    const r = await fetch("/api/studio/skills");
    const d = await r.json();
    renderTree(d.tree || []);
  }

  async function loadHealth() {
    try {
      const r = await fetch("/api/health");
      const h = await r.json();
      const b = h.llm_backend || "?";
      let ok = h.ok;
      let extra = "";
      if (b === "ollama") extra = h.ollama || "";
      if (b === "llama_cpp") extra = h.model_path ? "GGUF" : "нет файла";
      if (b === "openai_compatible") extra = h.openai || "";
      healthEl.textContent = `LLM: ${b} ${extra ? `(${extra})` : ""}`;
      healthEl.classList.toggle("ok", !!ok);
      healthEl.classList.toggle("bad", !ok);
    } catch (e) {
      healthEl.textContent = "Связь с сервером";
      healthEl.classList.add("bad");
    }
  }

  function fillTrainDatasetSelect(files) {
    const cur = trainDataset.value;
    trainDataset.innerHTML = "";
    const jsonl = (files || []).filter((f) => (f.name || "").toLowerCase().endsWith(".jsonl"));
    jsonl.forEach((f) => {
      const o = document.createElement("option");
      o.value = f.name;
      o.textContent = f.name;
      trainDataset.appendChild(o);
    });
    if (cur && jsonl.some((f) => f.name === cur)) trainDataset.value = cur;
    else if (jsonl.length === 0) {
      const o = document.createElement("option");
      o.value = "";
      o.textContent = "— нет .jsonl —";
      trainDataset.appendChild(o);
    }
  }

  async function loadTrainDeps() {
    try {
      const r = await fetch("/api/studio/train/deps");
      const d = await r.json();
      if (d.ok) {
        trainDepsEl.textContent = "Зависимости для обучения: OK";
        trainDepsEl.className = "train-deps ok";
      } else {
        trainDepsEl.textContent = `Нет пакетов: ${(d.missing || []).join(", ")}. ${d.hint || ""}`;
        trainDepsEl.className = "train-deps bad";
      }
    } catch (e) {
      trainDepsEl.textContent = "Не удалось проверить зависимости.";
      trainDepsEl.className = "train-deps bad";
    }
  }

  async function loadTrainLog() {
    try {
      const r = await fetch("/api/studio/train/log?tail=160");
      const d = await r.json();
      trainLogPre.textContent = d.text || "(пусто)";
    } catch (e) {
      trainLogPre.textContent = String(e.message);
    }
  }

  async function loadTrainStatus() {
    try {
      const r = await fetch("/api/studio/train/status");
      const st = await r.json();
      const state = st.state || "idle";
      const msg = st.message || "";
      trainStatusEl.textContent = `[${state}] ${msg}${st.output_dir ? ` → ${st.output_dir}` : ""}`;
      if (state === "running" || state === "queued") {
        if (!trainPollTimer)
          trainPollTimer = setInterval(() => {
            loadTrainStatus();
            loadTrainLog();
          }, 4000);
      } else if (trainPollTimer) {
        clearInterval(trainPollTimer);
        trainPollTimer = null;
      }
    } catch (e) {
      trainStatusEl.textContent = `Статус: ${e.message}`;
    }
  }

  async function loadFiles() {
    const r = await fetch("/api/studio/datasets");
    const d = await r.json();
    fileList.innerHTML = "";
    fillTrainDatasetSelect(d.files || []);
    (d.files || []).forEach((f) => {
      const row = document.createElement("div");
      row.className = "file-row";
      const left = document.createElement("span");
      left.textContent = `${f.name} (${Math.round(f.size / 1024)} KB)`;
      const del = document.createElement("button");
      del.type = "button";
      del.textContent = "Удалить";
      del.addEventListener("click", async () => {
        await fetch(`/api/studio/datasets/${encodeURIComponent(f.name)}`, { method: "DELETE" });
        loadFiles();
        log(`Удалено: ${f.name}`);
      });
      row.appendChild(left);
      row.appendChild(del);
      fileList.appendChild(row);
    });
    if (!d.files || !d.files.length) {
      fileList.innerHTML = '<p style="color:var(--muted);margin:0">Файлов пока нет.</p>';
    }
  }

  async function uploadFile(file) {
    if (!file) return;
    const fd = new FormData();
    fd.append("file", file);
    const r = await fetch("/api/studio/datasets/upload", { method: "POST", body: fd });
    if (!r.ok) {
      const t = await r.json().catch(() => ({}));
      log(`Ошибка загрузки: ${t.detail || r.status}`);
      return;
    }
    log(`Загружено: ${file.name}`);
    loadFiles();
  }

  dropzone.addEventListener("click", () => fileInput.click());
  fileInput.addEventListener("change", () => {
    uploadFile(fileInput.files[0]);
    fileInput.value = "";
  });
  ["dragover", "dragenter"].forEach((ev) => {
    dropzone.addEventListener(ev, (e) => {
      e.preventDefault();
      dropzone.classList.add("drag");
    });
  });
  ["dragleave", "drop"].forEach((ev) => {
    dropzone.addEventListener(ev, (e) => {
      e.preventDefault();
      dropzone.classList.remove("drag");
    });
  });
  dropzone.addEventListener("drop", (e) => {
    const f = e.dataTransfer.files[0];
    if (f) uploadFile(f);
  });

  btnBench.addEventListener("click", async () => {
    btnBench.disabled = true;
    log("Бенчмарк (eval)…");
    try {
      const r = await fetch("/api/studio/benchmark", { method: "POST" });
      const d = await r.json();
      if (!r.ok) throw new Error(d.detail || r.status);
      const res = d.result;
      log(`Бенчмарк: ${res.passed}/${res.total} (${res.percent}%)`);
      loadSkills();
    } catch (e) {
      log(`Ошибка бенчмарка: ${e.message}`);
    }
    btnBench.disabled = false;
  });

  btnExportLearn.addEventListener("click", async () => {
    btnExportLearn.disabled = true;
    try {
      const r = await fetch("/api/studio/export/learn", { method: "POST" });
      const d = await r.json();
      if (!r.ok) throw new Error(d.detail || r.status);
      log(`Экспорт журнала: ${d.path}`);
      loadFiles();
    } catch (e) {
      log(`Экспорт: ${e.message}`);
    }
    btnExportLearn.disabled = false;
  });

  btnRefresh.addEventListener("click", () => {
    loadSkills();
    loadFiles();
    loadHealth();
    loadTrainDeps();
    loadTrainStatus();
    loadTrainLog();
    log("Обновлено.");
  });

  btnTrainLog.addEventListener("click", () => {
    loadTrainLog();
    loadTrainStatus();
  });

  btnTrainStart.addEventListener("click", async () => {
    const dataset_file = trainDataset.value;
    if (!dataset_file) {
      log("Обучение: выберите .jsonl датасет.");
      return;
    }
    const base_model = (trainBase.value || "").trim();
    if (!base_model) {
      log("Обучение: укажите базовую модель (HF id).");
      return;
    }
    let learning_rate = parseFloat(trainLr.value);
    if (Number.isNaN(learning_rate)) learning_rate = 2e-4;
    btnTrainStart.disabled = true;
    try {
      const body = {
        base_model,
        dataset_file,
        run_name: (trainRun.value || "").trim(),
        epochs: parseFloat(trainEpochs.value) || 1,
        learning_rate,
        lora_r: parseInt(trainR.value, 10) || 8,
        lora_alpha: parseInt(trainAlpha.value, 10) || 16,
        max_seq_length: parseInt(trainSeq.value, 10) || 1024,
        per_device_train_batch_size: parseInt(trainBs.value, 10) || 1,
        gradient_accumulation_steps: parseInt(trainGa.value, 10) || 8,
        use_4bit: !!train4bit.checked,
      };
      const r = await fetch("/api/studio/train/start", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      const t = await r.json().catch(() => ({}));
      if (!r.ok) {
        let d = t.detail;
        if (Array.isArray(d)) d = d.map((x) => (x.msg ? `${x.loc?.join?.(".")}: ${x.msg}` : JSON.stringify(x))).join("; ");
        throw new Error(d || r.statusText || String(r.status));
      }
      log(`Обучение запущено: ${t.output_dir || ""}`);
      await loadTrainStatus();
      await loadTrainLog();
    } catch (e) {
      log(`Обучение: ${e.message}`);
    }
    btnTrainStart.disabled = false;
  });

  loadSkills();
  loadFiles();
  loadHealth();
  loadTrainDeps();
  loadTrainStatus();
  loadTrainLog();
})();
