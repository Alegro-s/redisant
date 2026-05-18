import { ROZA_API_BASE } from '../config/links';
import { getRozaAuthToken } from '../services/rozaAuthApi';

function apiUrl(path: string): string {
  const base = ROZA_API_BASE.replace(/\/$/, '');
  const segment = path.startsWith('/') ? path : `/${path}`;
  if (!base) return `/api${segment}`;
  return `${base}${segment}`;
}

export async function rozaChat(message: string, sessionId?: string): Promise<{ reply: string; sessionId?: string }> {
  const token = getRozaAuthToken();
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(apiUrl('/chat'), {
    method: 'POST',
    headers,
    credentials: 'include',
    body: JSON.stringify({
      text: message,
      session_id: sessionId ?? 'web',
    }),
  });

  if (!res.ok) {
    const err = await res.text().catch(() => '');
    throw new Error(err || `Ошибка сервера (${res.status})`);
  }

  const data = (await res.json()) as { reply?: string; answer?: string; session_id?: string };
  return {
    reply: (data.reply ?? data.answer ?? '').trim() || 'Пустой ответ сервера.',
    sessionId: data.session_id,
  };
}
