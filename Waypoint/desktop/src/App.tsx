import { useCallback, useEffect, useState } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { openUrl } from '@tauri-apps/plugin-opener';
import { CloudPanel } from './components/CloudPanel';
import type { CloudConfig } from './services/config';
import { defaultConfig } from './services/config';
import { loadConfig, saveConfig, loadSecure, saveSecure } from './services/store';
import { heartbeat, metricOpenUrl } from './services/cloud';
import { flushQueue, pushTelemetry } from './services/ingestQueue';
import { checkForUpdate } from './services/updates';

const VERSION = '0.1.0';
type Tab = 'cloud' | 'docker' | 'terminal' | 'liza' | 'about';

export default function App() {
  const [tab, setTab] = useState<Tab>('cloud');
  const [cfg, setCfg] = useState<CloudConfig>(defaultConfig());
  const [password, setPassword] = useState('');
  const [pairCode, setPairCode] = useState('');
  const [status, setStatus] = useState('');
  const [online, setOnline] = useState(navigator.onLine);
  const [dockerLines, setDockerLines] = useState<string[]>([]);
  const [termOut, setTermOut] = useState('');
  const [termCmd, setTermCmd] = useState('echo hello');
  const [updateInfo, setUpdateInfo] = useState<string | null>(null);

  const persist = useCallback(async (next: CloudConfig) => {
    setCfg(next);
    await saveConfig(next);
    if (next.apiKey) await saveSecure('api_key', next.apiKey);
    if (next.refreshToken) await saveSecure('refresh_token', next.refreshToken);
  }, []);

  useEffect(() => {
    (async () => {
      const loaded = await loadConfig();
      const apiKey = await loadSecure('api_key');
      const refreshToken = await loadSecure('refresh_token');
      if (!loaded.deviceId) {
        loaded.deviceId = `wd-${crypto.randomUUID().slice(0, 8)}`;
      }
      await persist({ ...loaded, apiKey: apiKey || loaded.apiKey, refreshToken: refreshToken || loaded.refreshToken });
    })();
  }, [persist]);

  useEffect(() => {
    const on = () => setOnline(true);
    const off = () => setOnline(false);
    window.addEventListener('online', on);
    window.addEventListener('offline', off);
    return () => {
      window.removeEventListener('online', on);
      window.removeEventListener('offline', off);
    };
  }, []);

  useEffect(() => {
    const t = setInterval(async () => {
      if (!cfg.apiKey) return;
      try {
        const flags = await heartbeat(cfg);
        if (flags) {
          const next = {
            ...cfg,
            syncTelemetry: flags.sync_telemetry,
            syncTasks: flags.sync_tasks,
            syncProjects: flags.sync_projects,
          };
          setCfg(next);
          await saveConfig(next);
        }
        if (cfg.syncTelemetry) await pushTelemetry(cfg, online);
        if (online) {
          const n = await flushQueue(cfg, true);
          if (n > 0) setStatus(`Отправлено из очереди: ${n}`);
        }
      } catch {
        /* offline queue */
      }
    }, 60_000);
    return () => clearInterval(t);
  }, [cfg, online]);

  useEffect(() => {
    checkForUpdate(cfg, VERSION).then((u) => {
      if (u) setUpdateInfo(`Доступна версия ${u.version}`);
    });
  }, [cfg.cloudUrl]);

  const openMetric = () => openUrl(metricOpenUrl(cfg, '/dashboard/settings/devices'));

  const refreshDocker = async () => {
    try {
      const lines = await invoke<string[]>('docker_ps');
      setDockerLines(lines);
    } catch (e) {
      setDockerLines([`Docker: ${e}`]);
    }
  };

  const runTerm = async () => {
    try {
      const out = await invoke<string>('run_shell', { command: termCmd });
      setTermOut(out);
    } catch (e) {
      setTermOut(String(e));
    }
  };

  const handleDeepLink = useCallback(async () => {
    try {
      const url = await invoke<string | null>('take_pending_deep_link');
      if (!url) return;
      const u = new URL(url);
      if (u.protocol === 'waypoint:' && u.hostname === 'pair') {
        const code = u.searchParams.get('code');
        if (code) setPairCode(code);
      }
    } catch {
      /* not in tauri */
    }
  }, []);

  useEffect(() => {
    handleDeepLink();
    const id = setInterval(handleDeepLink, 2000);
    return () => clearInterval(id);
  }, [handleDeepLink]);

  return (
    <div className="app">
      <header>
        <div>
          <h1>Waypoint Desktop</h1>
          <span>
            v{VERSION} · {online ? 'онлайн' : 'офлайн'}
            {updateInfo ? ` · ${updateInfo}` : ''}
          </span>
        </div>
        <button type="button" className="btn ghost" onClick={openMetric}>
          Открыть Metric
        </button>
      </header>

      <nav className="tabs">
        {(['cloud', 'docker', 'terminal', 'liza', 'about'] as Tab[]).map((t) => (
          <button key={t} type="button" className={tab === t ? 'active' : ''} onClick={() => setTab(t)}>
            {t === 'cloud' ? 'Облако' : t === 'docker' ? 'Docker' : t === 'terminal' ? 'Терминал' : t === 'liza' ? 'Liza' : 'О программе'}
          </button>
        ))}
      </nav>

      {tab === 'cloud' && (
        <CloudPanel
          cfg={cfg}
          setCfg={setCfg}
          password={password}
          setPassword={setPassword}
          pairCode={pairCode}
          setPairCode={setPairCode}
          status={status}
          setStatus={setStatus}
          persist={persist}
          onOpenMetric={openMetric}
        />
      )}

      {tab === 'docker' && (
        <div className="panel">
          <div className="row">
            <button type="button" className="btn" onClick={refreshDocker}>
              Обновить docker ps
            </button>
          </div>
          {dockerLines.map((l) => (
            <div key={l} className="docker-line">
              {l}
            </div>
          ))}
        </div>
      )}

      {tab === 'terminal' && (
        <div className="panel">
          <label>Команда (PowerShell / sh)</label>
          <input type="text" value={termCmd} onChange={(e) => setTermCmd(e.target.value)} />
          <button type="button" className="btn" onClick={runTerm}>
            Выполнить
          </button>
          <pre className="log">{termOut}</pre>
        </div>
      )}

      {tab === 'liza' && (
        <div className="panel">
          <label>Endpoint Liza (Ollama / OpenAI-compatible)</label>
          <input
            type="url"
            value={cfg.lizaEndpoint}
            onChange={(e) => setCfg({ ...cfg, lizaEndpoint: e.target.value })}
            onBlur={() => persist(cfg)}
          />
          <p className="status">Локальный ассистент использует этот URL. Облачная Liza в Metric — отдельно.</p>
        </div>
      )}

      {tab === 'about' && (
        <div className="panel">
          <p>Waypoint Desktop — локальный клиент серии Waypoint.</p>
          <p className="status">Device ID: {cfg.deviceId}</p>
          <a href={`${cfg.cloudUrl}/desktop/docs/cloud`} style={{ color: 'var(--accent-soft)' }}>
            Документация: связь с облаком
          </a>
        </div>
      )}
    </div>
  );
}
