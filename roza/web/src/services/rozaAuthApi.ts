import { resolveAuthBase } from '../utils/authBase';

const headers = () => ({
  'Content-Type': 'application/json',
  'X-Client-Realm': 'roza',
});

function authHeaders(token?: string) {
  const h: Record<string, string> = { ...headers() };
  if (token) h.Authorization = `Bearer ${token}`;
  return h;
}

function mapAuthErrorMessage(raw: string): string {
  if (raw === 'Email or nickname already taken') {
    return 'Этот email или ник уже занят. Если вы уже регистрировались — войдите.';
  }
  if (raw.includes('email уже зарегистрирован') || raw.includes('никнейм уже занят')) {
    return raw;
  }
  if (raw.startsWith('Invalid login or password')) {
    return 'Неверный email или пароль.';
  }
  if (raw.includes('Пароль')) {
    return raw;
  }
  return raw;
}

async function parseError(res: Response): Promise<string> {
  const data = (await res.json().catch(() => ({}))) as { error?: string; message?: string };
  const raw = data.error ?? data.message ?? `Ошибка ${res.status}`;
  return mapAuthErrorMessage(raw);
}

export type RozaQuota = {
  plan: string;
  tokens_used: number;
  tokens_limit: number;
  tokens_remaining: number;
  external_api: boolean;
};

export async function rozaLogin(login: string, password: string): Promise<{ token: string }> {
  const res = await fetch(`${resolveAuthBase()}/login`, {
    method: 'POST',
    headers: headers(),
    credentials: 'include',
    body: JSON.stringify({ login: login.trim(), password }),
  });
  const data = (await res.json().catch(() => ({}))) as {
    token?: string;
    error?: string;
    error_code?: string;
    email?: string;
  };
  if (!res.ok) {
    if (data.error_code === 'email_not_verified') {
      throw new Error(`EMAIL_NOT_VERIFIED:${data.email ?? login}`);
    }
    throw new Error(await parseError(res));
  }
  if (!data.token) throw new Error('Сервер не вернул токен');
  return { token: data.token };
}

export type RegisterPayload = {
  email: string;
  nickname: string;
  full_name: string;
  password: string;
  phone?: string;
};

export async function rozaRegister(payload: RegisterPayload): Promise<{ status?: string; email?: string; token?: string }> {
  const res = await fetch(`${resolveAuthBase()}/register`, {
    method: 'POST',
    headers: headers(),
    credentials: 'include',
    body: JSON.stringify({
      email: payload.email.trim().toLowerCase(),
      nickname: payload.nickname.trim(),
      full_name: payload.full_name.trim(),
      password: payload.password,
      phone: payload.phone?.trim() || null,
      settings: {},
    }),
  });
  const data = (await res.json().catch(() => ({}))) as { status?: string; email?: string; token?: string; error?: string };
  if (!res.ok) {
    throw new Error(data.error ? mapAuthErrorMessage(data.error) : `Ошибка ${res.status}`);
  }
  return data;
}

export async function rozaVerifyEmail(email: string, code: string): Promise<{ token: string }> {
  const res = await fetch(`${resolveAuthBase()}/auth/register/verify`, {
    method: 'POST',
    headers: headers(),
    credentials: 'include',
    body: JSON.stringify({ email: email.trim().toLowerCase(), code: code.replace(/\s/g, '') }),
  });
  const data = (await res.json().catch(() => ({}))) as { token?: string; error?: string };
  if (!res.ok) throw new Error(data.error ?? 'Неверный код');
  if (!data.token) throw new Error('Сервер не вернул токен');
  return { token: data.token };
}

export async function rozaResendVerification(email: string): Promise<void> {
  const res = await fetch(`${resolveAuthBase()}/auth/register/resend`, {
    method: 'POST',
    headers: headers(),
    credentials: 'include',
    body: JSON.stringify({ email: email.trim().toLowerCase() }),
  });
  if (!res.ok) throw new Error(await parseError(res));
}

export async function rozaFetchQuota(token: string): Promise<RozaQuota> {
  const res = await fetch(`${resolveAuthBase()}/me/roza/quota`, {
    headers: authHeaders(token),
    credentials: 'include',
  });
  if (!res.ok) throw new Error(await parseError(res));
  return res.json() as Promise<RozaQuota>;
}

export async function rozaStartCheckout(token: string, plan = 'pro'): Promise<{ checkout_url?: string; mode?: string }> {
  const res = await fetch(`${resolveAuthBase()}/me/roza/billing/checkout`, {
    method: 'POST',
    headers: authHeaders(token),
    credentials: 'include',
    body: JSON.stringify({ plan, provider: 'yookassa' }),
  });
  const data = (await res.json().catch(() => ({}))) as { checkout_url?: string; mode?: string; error?: string };
  if (!res.ok) throw new Error(data.error ?? 'Ошибка оплаты');
  return data;
}

export function saveRozaSession(token: string, login: string) {
  localStorage.setItem('roza_auth_token', token);
  localStorage.setItem('roza_auth_login', login);
}

export function clearRozaSession() {
  localStorage.removeItem('roza_auth_token');
  localStorage.removeItem('roza_auth_login');
}

export function loadRozaSession(): { token: string; login: string } | null {
  const token = localStorage.getItem('roza_auth_token') ?? '';
  const login = localStorage.getItem('roza_auth_login') ?? '';
  if (!token) return null;
  return { token, login };
}

export function getRozaAuthToken(): string | null {
  return localStorage.getItem('roza_auth_token');
}
