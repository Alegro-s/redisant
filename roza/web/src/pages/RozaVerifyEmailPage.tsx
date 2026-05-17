import { FormEvent, useEffect, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { RozaMark } from '../components/roza/RozaMark';
import { rozaResendVerification, rozaVerifyEmail, saveRozaSession } from '../services/rozaAuthApi';

export function RozaVerifyEmailPage() {
  const [params] = useSearchParams();
  const navigate = useNavigate();
  const [email, setEmail] = useState(params.get('email') ?? '');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [ok, setOk] = useState('');
  const [busy, setBusy] = useState(false);
  const [resendSec, setResendSec] = useState(0);

  useEffect(() => {
    if (resendSec <= 0) return;
    const t = setTimeout(() => setResendSec((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [resendSec]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      const { token } = await rozaVerifyEmail(email, code);
      saveRozaSession(token, email.trim());
      setOk('Email подтверждён. Можно войти в приложение Roza AI.');
      setTimeout(() => navigate('/account'), 1200);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Ошибка');
    } finally {
      setBusy(false);
    }
  }

  async function resend() {
    if (resendSec > 0) return;
    setError('');
    try {
      await rozaResendVerification(email);
      setResendSec(60);
      setOk('Код отправлен повторно.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Ошибка');
    }
  }

  return (
    <main className="roza-main roza-account-page roza-hub-google">
      <section className="roza-account-hero">
        <RozaMark variant="ai" size={48} />
        <p className="roza-hub-waypoint">Waypoint · Roza</p>
        <h1>Подтверждение email</h1>
        <p className="roza-account-lead">Введите 8-значный код из письма — без этого вход в Roza AI недоступен.</p>
      </section>
      <div className="roza-account-card">
        <form className="roza-account-form" onSubmit={onSubmit}>
          <label>
            Email
            <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required autoComplete="email" />
          </label>
          <label>
            Код
            <input value={code} onChange={(e) => setCode(e.target.value)} required inputMode="numeric" maxLength={12} />
          </label>
          {error ? <p className="roza-account-error">{error}</p> : null}
          {ok ? <p className="roza-account-ok">{ok}</p> : null}
          <button type="submit" className="roza-account-btn roza-account-btn-primary" disabled={busy}>
            {busy ? '…' : 'Подтвердить'}
          </button>
          <button type="button" className="roza-account-btn" disabled={resendSec > 0} onClick={() => void resend()}>
            {resendSec > 0 ? `Повтор через ${resendSec} с` : 'Отправить код снова'}
          </button>
        </form>
      </div>
      <p className="roza-ai-footer-links">
        <Link to="/account">← Кабинет</Link>
      </p>
    </main>
  );
}
