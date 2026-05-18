import { useState } from 'react';
import type { CloudConfig } from '../services/config';
import { resolveCloudUrls } from '../services/config';
import { claimPairing, login } from '../services/cloud';

type Props = {
  cfg: CloudConfig;
  password: string;
  setPassword: (v: string) => void;
  pairCode: string;
  setPairCode: (v: string) => void;
  status: string;
  setStatus: (v: string) => void;
  setCfg: (next: CloudConfig) => void;
  persist: (next: CloudConfig) => Promise<void>;
  onOpenMetric: () => void;
};

export function CloudPanel({
  cfg,
  password,
  setPassword,
  pairCode,
  setPairCode,
  status,
  setStatus,
  setCfg,
  persist,
  onOpenMetric,
}: Props) {
  const [showCode, setShowCode] = useState(false);
  const paired = Boolean(cfg.apiKey);
  const loggedIn = Boolean(cfg.accessToken);

  const applyCloudUrl = async (url: string) => {
    await persist({ ...cfg, ...resolveCloudUrls(url) });
  };

  const doLogin = async () => {
    setStatus('Вход…');
    try {
      const withUrls = { ...cfg, ...resolveCloudUrls(cfg.cloudUrl) };
      const token = await login(withUrls, withUrls.email, password);
      await persist({ ...withUrls, accessToken: token });
      setPassword('');
      setStatus('Вы вошли');
    } catch (e) {
      setStatus(`Ошибка: ${e}`);
    }
  };

  const doLogout = async () => {
    await persist({
      ...cfg,
      accessToken: '',
      refreshToken: '',
      apiKey: '',
    });
    setStatus('Выход выполнен');
  };

  const doPair = async () => {
    setStatus('Привязка…');
    try {
      const withUrls = { ...cfg, ...resolveCloudUrls(cfg.cloudUrl) };
      const res = await claimPairing(withUrls, pairCode, withUrls.deviceId, withUrls.deviceName);
      await persist({
        ...withUrls,
        apiKey: res.api_key,
        accessToken: res.access_token,
        refreshToken: res.refresh_token,
        cloudUrl: res.cloud_url || withUrls.cloudUrl,
      });
      setPairCode('');
      setStatus('Устройство подключено к облаку');
    } catch (e) {
      setStatus(`Ошибка: ${e}`);
    }
  };

  return (
    <div className="cloud-panel">
      <div className="cloud-login-card">
        <h2 className="cloud-login-title">Вход в Waypoint</h2>
        <p className="cloud-login-sub">Тот же email и пароль, что на Waypoint Metric</p>

        <label htmlFor="cloud-url">Сайт Metric</label>
        <input
          id="cloud-url"
          type="url"
          value={cfg.cloudUrl}
          onChange={(e) => setCfg({ ...cfg, cloudUrl: e.target.value })}
          onBlur={(e) => applyCloudUrl(e.target.value)}
          placeholder="https://metrika-waypoint.ru"
        />

        <label htmlFor="cloud-email">Email</label>
        <input
          id="cloud-email"
          type="email"
          autoComplete="username"
          value={cfg.email}
          onChange={(e) => setCfg({ ...cfg, email: e.target.value })}
          onBlur={() => persist(cfg)}
        />

        <label htmlFor="cloud-pass">Пароль</label>
        <input
          id="cloud-pass"
          type="password"
          autoComplete="current-password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && doLogin()}
        />

        <div className="cloud-login-actions">
          <button type="button" className="btn" onClick={doLogin} disabled={!cfg.email || !password}>
            Войти
          </button>
          {loggedIn && (
            <button type="button" className="btn ghost" onClick={doLogout}>
              Выйти
            </button>
          )}
        </div>
      </div>

      <div className="cloud-status-block">
        {paired ? (
          <>
            <p className="status ok">Облако подключено</p>
            <p className="cloud-hint">
              Синхронизацию настраивайте в Metric:{' '}
              <button type="button" className="link-btn" onClick={onOpenMetric}>
                Настройки → Подключённые устройства
              </button>
            </p>
          </>
        ) : (
          <>
            <p className="cloud-hint">
              Привязку ПК сделайте в Metric: создайте код WD-… и нажмите «Открыть в Desktop».
            </p>
            <button type="button" className="btn" onClick={onOpenMetric}>
              Открыть настройки в Metric
            </button>
            <button type="button" className="btn ghost" onClick={() => setShowCode((v) => !v)}>
              {showCode ? 'Скрыть код' : 'Ввести код вручную'}
            </button>
            {showCode && (
              <div className="cloud-code-row">
                <input
                  type="text"
                  value={pairCode}
                  onChange={(e) => setPairCode(e.target.value)}
                  placeholder="WD-XXXXXXXX"
                />
                <button type="button" className="btn" onClick={doPair} disabled={!pairCode.trim()}>
                  Привязать
                </button>
              </div>
            )}
          </>
        )}
        {status && <p className={`status ${status.includes('Ошибка') ? 'err' : 'ok'}`}>{status}</p>}
      </div>
    </div>
  );
}
