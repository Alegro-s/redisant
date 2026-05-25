import { FormEvent, useEffect, useState } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { RozaMark } from '../components/roza/RozaMark';
import {
  clearRozaSession,
  loadRozaSession,
  rozaFetchQuota,
  rozaLogin,
  rozaRegister,
  saveRozaSession,
  type RozaQuota,
} from '../services/rozaAuthApi';

export function RozaAccountPage() {
  const [params] = useSearchParams();
  const session = loadRozaSession();
  const [mode, setMode] = useState<'login' | 'register'>('login');
  const [email, setEmail] = useState('');
  const [nickname, setNickname] = useState('');
  const [fullName, setFullName] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');
  const [quota, setQuota] = useState<RozaQuota | null>(null);

  useEffect(() => {
    if (!session?.token) return;
    void rozaFetchQuota(session.token)
      .then(setQuota)
      .catch(() => setQuota(null));
    if (params.get('billing_demo') === '1' || params.get('paid') === '1') {
      setOk('Подписка обновляется. Обновите страницу через несколько секунд.');
    }
  }, [session?.token, params]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setOk('');
    setBusy(true);
    try {
      if (mode === 'login') {
        const loginStr = email.trim();
        const { token } = await rozaLogin(loginStr, password);
        saveRozaSession(token, loginStr);
        window.location.reload();
        return;
      }
      const data = await rozaRegister({
        email: email.trim(),
        nickname: nickname.trim(),
        full_name: fullName.trim() || nickname.trim(),
        password,
      });
      if (data.status === 'pending_verification') {
        window.location.href = `/verify-email?email=${encodeURIComponent(data.email ?? email)}`;
        return;
      }
      if (data.token) {
        saveRozaSession(data.token, email.trim());
        window.location.reload();
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Ошибка';
      if (msg.startsWith('EMAIL_NOT_VERIFIED:')) {
        const em = msg.split(':')[1] ?? email;
        window.location.href = `/verify-email?email=${encodeURIComponent(em)}`;
        return;
      }
      setError(msg);
    } finally {
      setBusy(false);
    }
  }

  function signOut() {
    clearRozaSession();
    window.location.reload();
  }

  return (
    <main className="roza-main roza-account-page roza-hub-google">
      <div className="roza-account-layout">
      <section className="roza-account-hero">
        <RozaMark variant="ai" size={52} />
        <p className="roza-hub-waypoint">Waypoint · Roza</p>
        <h1>Личный кабинет Roza AI</h1>
        <p className="roza-account-lead">
          Один аккаунт для сайта и приложения Windows.
        </p>
      </section>

      <div className="roza-account-card">
      {session ? (
        <div className="roza-account-signed">
          <p>
            Вы вошли как <strong>{session.login}</strong>
          </p>
          {quota ? (
            <p className="roza-account-quota">
              Тариф <strong>{quota.plan}</strong> · токены сегодня:{' '}
              <strong>
                {quota.tokens_remaining.toLocaleString('ru-RU')}
              </strong>{' '}
              из {quota.tokens_limit.toLocaleString('ru-RU')}
              {quota.external_api ? ' · внешние модели по API включены' : ''}
            </p>
          ) : null}
          <div className="roza-account-actions">
            <button type="button" className="roza-account-btn roza-account-btn-primary" onClick={signOut}>
              Выйти
            </button>
            <Link to="/ai" className="roza-account-btn">
              Roza AI
            </Link>
          </div>
          {ok ? <p className="roza-account-ok">{ok}</p> : null}
        </div>
      ) : (
        <form className="roza-account-form" onSubmit={onSubmit}>
          <div className="roza-account-tabs">
            <button type="button" className={mode === 'login' ? 'active' : undefined} onClick={() => setMode('login')}>
              Вход
            </button>
            <button type="button" className={mode === 'register' ? 'active' : undefined} onClick={() => setMode('register')}>
              Регистрация
            </button>
          </div>
          <label>
            Email
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoComplete="username" required />
          </label>
          {mode === 'register' ? (
            <>
              <label>
                Никнейм
                <input value={nickname} onChange={(e) => setNickname(e.target.value)} required minLength={2} maxLength={32} />
              </label>
              <label>
                Имя
                <input value={fullName} onChange={(e) => setFullName(e.target.value)} placeholder="Как к вам обращаться" />
              </label>
            </>
          ) : null}
          <label>
            Пароль
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
              required
              minLength={mode === 'register' ? 10 : 1}
            />
          </label>
          {mode === 'register' ? (
            <p className="roza-account-note">
              Пароль: от 10 символов, заглавная и строчная латиница, цифра и спецсимвол (!@#$…).
            </p>
          ) : null}
          {error ? <p className="roza-account-error">{error}</p> : null}
          <button type="submit" className="roza-account-btn roza-account-btn-primary" disabled={busy}>
            {busy ? '…' : mode === 'login' ? 'Войти' : 'Зарегистрироваться'}
          </button>
        </form>
      )}
      </div>

      <section className="roza-account-sections">
        <article>
          <h2>Приложение Roza AI</h2>
          <p>Тот же логин и пароль — в десктоп-консультанте: документы, ПК и студия обучения.</p>
        </article>
        <article>
          <h2>Тарифы</h2>
          <p>Подписка и оплата появятся позже. Сейчас действует бесплатный дневной лимит токенов.</p>
        </article>
      </section>
      </div>

      <p className="roza-ai-footer-links">
        <Link to="/ai">Roza AI</Link>
        <Link to="/">На главную</Link>
      </p>
    </main>
  );
}
