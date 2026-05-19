import { useState } from 'react';
import { openUrl } from '@tauri-apps/plugin-opener';
import type { CloudConfig } from '../services/config';
import { resolveCloudUrls } from '../services/config';
import { login, metricOpenUrl } from '../services/cloud';

type Props = {
  cfg: CloudConfig;
  setCfg: (c: CloudConfig) => void;
  persist: (c: CloudConfig) => Promise<void>;
  onSignedIn: () => void;
};

export function AuthScreen({ cfg, setCfg, persist, onSignedIn }: Props) {
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const signIn = async () => {
    setError('');
    if (!cfg.email.trim() || !password) {
      setError('Введите email и пароль.');
      return;
    }
    setBusy(true);
    try {
      const withUrls = { ...cfg, ...resolveCloudUrls(cfg.cloudUrl) };
      const token = await login(withUrls, withUrls.email, password);
      await persist({ ...withUrls, accessToken: token });
      setPassword('');
      onSignedIn();
    } catch (e) {
      setError(String(e));
    } finally {
      setBusy(false);
    }
  };

  const openRegister = () => {
    const urls = resolveCloudUrls(cfg.cloudUrl);
    openUrl(metricOpenUrl({ ...cfg, ...urls }, '/register'));
  };

  return (
    <div className="auth-screen">
      <div className="auth-card">
        <div className="auth-brand">
          <img src="/logo.svg" alt="" className="auth-logo" width={72} height={72} />
          <h1>Waypoint Desktop</h1>
          <p>Локальное приложение · Waypoint Metric</p>
        </div>

        <p className="auth-hint">Войдите тем же аккаунтом, что на сайте Metric. Регистрация — в браузере.</p>

        <label htmlFor="auth-email">Email</label>
        <input
          id="auth-email"
          className="auth-field"
          type="email"
          autoComplete="username"
          placeholder="you@example.com"
          value={cfg.email}
          onChange={(e) => setCfg({ ...cfg, email: e.target.value })}
        />

        <label htmlFor="auth-pass">Пароль</label>
        <input
          id="auth-pass"
          className="auth-field"
          type="password"
          autoComplete="current-password"
          placeholder="Пароль"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && signIn()}
        />

        {error && <p className="auth-error">{error}</p>}

        <button type="button" className="auth-btn-primary" onClick={signIn} disabled={busy}>
          {busy ? 'Вход…' : 'Войти'}
        </button>

        <button type="button" className="auth-btn-ghost" onClick={openRegister} disabled={busy}>
          Создать аккаунт на сайте
        </button>
      </div>
    </div>
  );
}
