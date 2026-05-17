const SESSION_KEY = 'lynx_hub_admin';

/** Пароль задаётся в VITE_HUB_ADMIN_PASSWORD; без него вход недоступен */
const ADMIN_PASSWORD = import.meta.env.VITE_HUB_ADMIN_PASSWORD ?? '';

export function isHubAdmin(): boolean {
  return sessionStorage.getItem(SESSION_KEY) === '1';
}

export function loginHubAdmin(password: string): boolean {
  if (!ADMIN_PASSWORD || password !== ADMIN_PASSWORD) return false;
  sessionStorage.setItem(SESSION_KEY, '1');
  return true;
}

export function logoutHubAdmin(): void {
  sessionStorage.removeItem(SESSION_KEY);
}

export function hubAdminConfigured(): boolean {
  return Boolean(ADMIN_PASSWORD);
}
