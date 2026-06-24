(function () {
  function apiUrl() {
    if (window.NT_API_URL) return String(window.NT_API_URL).replace(/\/$/, "");
    if (window.NT_API_BASE) return String(window.NT_API_BASE).replace(/\/$/, "");
    return String(window.location.origin).replace(/\/$/, "");
  }

  function adminEntryUrl() {
    var base = window.NT_ADMIN_BASE || "/admin/";
    return window.location.origin + base.replace(/\/$/, "") + "/?key=ВАШ_КЛЮЧ";
  }

  function getKey() {
    var q = new URLSearchParams(window.location.search);
    var key = q.get("key") || q.get("adminKey");
    if (key) {
      try {
        sessionStorage.setItem("nt_admin_key", key);
      } catch (_) {}
      return key;
    }
    try {
      return sessionStorage.getItem("nt_admin_key") || "";
    } catch (_) {
      return "";
    }
  }

  function applyKeyUi() {
    var key = getKey();
    document.documentElement.classList.remove("nt-no-key", "nt-has-key");
    document.documentElement.classList.add(key ? "nt-has-key" : "nt-no-key");
    if (!key) {
      var sample = document.getElementById("login-no-key-url");
      if (sample) sample.textContent = adminEntryUrl();
    }
    return key;
  }

  function showError(msg) {
    var el = document.getElementById("login-error");
    if (!el) return;
    el.textContent = msg;
    el.hidden = false;
  }

  function clearError() {
    var el = document.getElementById("login-error");
    if (el) el.hidden = true;
  }

  function unlock(session) {
    try {
      sessionStorage.setItem("nt_admin_session", session);
    } catch (_) {}
    document.getElementById("login-gate")?.classList.add("login-gate--hidden");
    document.getElementById("app")?.classList.remove("app--locked");
    window.dispatchEvent(new CustomEvent("nt-auth-ok"));
  }

  var qrPollTimer = null;

  function renderQrClient(box, url) {
    box.innerHTML = "";
    if (!window.QrCreator) return false;
    try {
      var canvas = document.createElement("canvas");
      canvas.width = 200;
      canvas.height = 200;
      QrCreator.render(
        {
          text: url,
          radius: 0.35,
          ecLevel: "M",
          fill: "#141414",
          background: "#ffffff",
          size: 200,
        },
        canvas
      );
      box.appendChild(canvas);
      return true;
    } catch (e) {
      console.error("QR render failed", e);
      return false;
    }
  }

  function renderQrLink(box, url) {
    var safe = encodeURI(url);
    box.innerHTML =
      '<a class="login-qr-link" href="' +
      safe +
      '" target="_blank" rel="noopener noreferrer">Открыть на телефоне</a>';
  }

  function renderQr(challenge, confirmUrl) {
    var box = document.getElementById("login-qr-canvas");
    if (!box) return;

    if (renderQrClient(box, confirmUrl)) return;

    box.innerHTML = "";
    var img = document.createElement("img");
    img.width = 200;
    img.height = 200;
    img.alt = "QR";
    img.onload = function () {
      fetch(apiUrl() + "/api/admin/auth/qr/svg/" + encodeURIComponent(challenge))
        .then(function (r) {
          return r.text();
        })
        .then(function (svg) {
          if (svg.indexOf("<text") >= 0) {
            if (!renderQrClient(box, confirmUrl)) renderQrLink(box, confirmUrl);
          }
        })
        .catch(function () {
          if (!renderQrClient(box, confirmUrl)) renderQrLink(box, confirmUrl);
        });
    };
    img.onerror = function () {
      if (!renderQrClient(box, confirmUrl)) renderQrLink(box, confirmUrl);
    };
    img.src = apiUrl() + "/api/admin/auth/qr/svg/" + encodeURIComponent(challenge) + "?t=" + Date.now();
    box.appendChild(img);
  }

  function startQr() {
    var key = getKey();
    if (!key) {
      applyKeyUi();
      showError("Откройте " + adminEntryUrl().replace(window.location.origin, "") + " один раз");
      return;
    }
    clearError();
    var hint = document.getElementById("login-qr-hint");
    if (hint) hint.textContent = "Генерация QR…";

    fetch(apiUrl() + "/api/admin/auth/qr/start", {
      method: "POST",
      headers: { "X-Admin-Key": key },
    })
      .then(function (res) {
        if (!res.ok) {
          return res.json().catch(function () { return {}; }).then(function (err) {
            var msg = err.detail || "Не удалось создать QR";
            if (res.status === 401) msg = "Неверный ключ — откройте " + adminEntryUrl().replace(window.location.origin, "").replace("ВАШ_КЛЮЧ", "ПРАВИЛЬНЫЙ_КЛЮЧ");
            throw new Error(msg);
          });
        }
        return res.json();
      })
      .then(function (data) {
        var url = data.confirm_url || apiUrl() + "/api/admin/auth/qr/confirm-page?challenge=" + encodeURIComponent(data.challenge);
        renderQr(data.challenge, url);
        if (hint) hint.textContent = "Сканируйте телефоном и подтвердите отпечатком";
        if (qrPollTimer) clearInterval(qrPollTimer);
        qrPollTimer = setInterval(function () {
          fetch(apiUrl() + "/api/admin/auth/qr/poll/" + encodeURIComponent(data.challenge), {
            headers: { "X-Admin-Key": key },
          })
            .then(function (r) {
              return r.ok ? r.json() : null;
            })
            .then(function (st) {
              if (!st) return;
              if (st.status === "ok" && st.session) {
                clearInterval(qrPollTimer);
                qrPollTimer = null;
                unlock(st.session);
              }
              if (st.status === "expired") {
                clearInterval(qrPollTimer);
                qrPollTimer = null;
                showError("QR истёк — нажмите «Обновить QR»");
              }
            });
        }, 2000);
      })
      .catch(function (e) {
        showError(e.message || "Нет связи с API");
        if (hint) hint.textContent = "";
      });
  }

  function loginPassword(e) {
    e.preventDefault();
    var key = getKey();
    if (!key) {
      applyKeyUi();
      showError("Откройте " + adminEntryUrl().replace(window.location.origin, "") + " один раз");
      return;
    }
    clearError();
    var user = document.getElementById("login-user")?.value?.trim() || "root";
    var pass = document.getElementById("login-pass")?.value || "";

    fetch(apiUrl() + "/api/admin/auth/login", {
      method: "POST",
      headers: {
        "X-Admin-Key": key,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ username: user, password: pass }),
    })
      .then(function (res) {
        if (!res.ok) {
          return res.json().catch(function () { return {}; }).then(function (err) {
            var msg = err.detail || "Ошибка входа";
            if (res.status === 401) {
              msg = err.detail === "Неверный логин или пароль"
                ? "Неверный логин или пароль (root / root)"
                : "Неверный ключ — откройте " + adminEntryUrl().replace(window.location.origin, "").replace("ВАШ_КЛЮЧ", "ПРАВИЛЬНЫЙ_КЛЮЧ");
            }
            throw new Error(msg);
          });
        }
        return res.json();
      })
      .then(function (data) {
        if (data.session) unlock(data.session);
        else showError("Нет сессии от сервера");
      })
      .catch(function (err) {
        showError(err.message || "Нет связи с API");
      });
  }

  function switchTab(id) {
    document.querySelectorAll("[data-login-tab]").forEach(function (b) {
      b.classList.toggle("login-tab--active", b.getAttribute("data-login-tab") === id);
    });
    document.querySelectorAll("[data-login-panel]").forEach(function (p) {
      p.hidden = p.getAttribute("data-login-panel") !== id;
    });
    if (id === "qr") startQr();
  }

  applyKeyUi();

  var gate = document.getElementById("login-gate");
  if (gate) {
    gate.addEventListener("click", function (e) {
      var tab = e.target.closest("[data-login-tab]");
      if (tab) switchTab(tab.getAttribute("data-login-tab"));
    });
    document.getElementById("btn-qr-start")?.addEventListener("click", startQr);
    document.getElementById("login-form")?.addEventListener("submit", loginPassword);
  }

  window.ntApplyKeyUi = applyKeyUi;
  window.ntStartQr = startQr;
  window.ntGetAdminKey = getKey;
})();
