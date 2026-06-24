import { resolveLynxAuthBase } from '../utils/authBase';
import {
  ENGINE_MANIFEST_URL,
  LYNX_LAUNCHER_APK_URL,
  LYNX_LAUNCHER_EXE_URL,
} from '../config/links';
import { hubApiConfigured } from './hubApi';
import { hubAdminConfigured } from './hubAdminAuth';
import { getLynxAuthToken } from './lynxAuth';

const API_BASE = (import.meta.env.VITE_LYNX_API_BASE ?? '/lynx').replace(/\/$/, '');

export type ServiceStatusItem = {
  id: string;
  title: string;
  ok: boolean;
  required: boolean;
  hint: string;
};

async function probe(url: string, init?: RequestInit): Promise<boolean> {
  try {
    const res = await fetch(url, { ...init, credentials: 'include' });
    return res.ok;
  } catch {
    return false;
  }
}

/** Что нужно для работы Hub Operations (проверки из браузера + env сборки). */
export async function fetchHubServiceStatus(isOps: boolean): Promise<ServiceStatusItem[]> {
  const authBase = resolveLynxAuthBase();
  const hasToken = Boolean(getLynxAuthToken());
  const buildAdminToken = Boolean(import.meta.env.VITE_HUB_ADMIN_TOKEN?.trim());
  const buildAdminPassword = hubAdminConfigured();

  const [authHealth, lynxHealth, hubContent, hubCatalog] = await Promise.all([
    probe(`${authBase}/health`),
    probe(`${API_BASE}/health`),
    probe(`${API_BASE}/v1/hub/content`),
    probe(`${API_BASE}/v1/hub/marketplace-catalog`),
  ]);

  const writeOk = hubApiConfigured() && (isOps || buildAdminToken);

  return [
    {
      id: 'auth-api',
      title: 'Auth API (/auth)',
      ok: authHealth,
      required: true,
      hint: authHealth
        ? 'Авторизация Hub доступна'
        : 'Поднимите auth-api :8090 и nginx location /auth/',
    },
    {
      id: 'lynx-api',
      title: 'Lynx API (/lynx)',
      ok: lynxHealth,
      required: true,
      hint: lynxHealth
        ? 'API отвечает на /lynx/health'
        : 'docker compose apis + nginx proxy /lynx/ → :8082',
    },
    {
      id: 'hub-read',
      title: 'Контент Hub (GET)',
      ok: hubContent && hubCatalog,
      required: true,
      hint:
        hubContent && hubCatalog
          ? 'Новости и каталог читаются с API'
          : 'Проверьте lynx-api и volume lynx_uploads (hub JSON)',
    },
    {
      id: 'hub-write',
      title: 'Публикация (PUT)',
      ok: writeOk,
      required: true,
      hint: writeOk
        ? 'Сохранение контента разрешено'
        : 'Нужен JWT nexus ИЛИ совпадение LYNX_HUB_ADMIN_TOKEN ↔ VITE_HUB_ADMIN_TOKEN',
    },
    {
      id: 'nexus-login',
      title: 'Вход NEXUS (JWT)',
      ok: isOps && hasToken,
      required: false,
      hint:
        isOps && hasToken
          ? 'Роль nexus/admin — публикация без build-токена'
          : 'LYNX_OPS_EMAILS в smtp.env + promote SQL для вашего email',
    },
    {
      id: 'build-token',
      title: 'VITE_HUB_ADMIN_TOKEN (сборка Hub)',
      ok: buildAdminToken,
      required: false,
      hint: buildAdminToken
        ? 'Токен вшит при npm run build'
        : 'Добавьте LYNX_HUB_ADMIN_TOKEN в smtp.env и пересоберите Hub',
    },
    {
      id: 'dev-password',
      title: 'VITE_HUB_ADMIN_PASSWORD (локально)',
      ok: buildAdminPassword,
      required: false,
      hint: buildAdminPassword
        ? 'Пароль разработки для /admin без аккаунта'
        : 'Только для dev-сборки; на проде используйте NEXUS',
    },
    {
      id: 'launcher-exe',
      title: 'Ссылка Launcher EXE',
      ok: Boolean(LYNX_LAUNCHER_EXE_URL?.trim()),
      required: false,
      hint: LYNX_LAUNCHER_EXE_URL || 'VITE_LYNX_LAUNCHER_EXE_URL или push-lynx-update-to-server.ps1',
    },
    {
      id: 'launcher-apk',
      title: 'Ссылка Launcher APK',
      ok: Boolean(LYNX_LAUNCHER_APK_URL?.trim()),
      required: false,
      hint: LYNX_LAUNCHER_APK_URL || 'Загрузите APK в /srv/lynx-hub/dist/downloads/',
    },
    {
      id: 'engine-manifest',
      title: 'Манифест движка',
      ok: Boolean(ENGINE_MANIFEST_URL?.trim()),
      required: false,
      hint: ENGINE_MANIFEST_URL || 'engine-manifest.json на Hub CDN или policy в Cloud Admin',
    },
    {
      id: 's3',
      title: 'S3 (Timeweb) на lynx-api',
      ok: false,
      required: false,
      hint: 'LYNX_S3_* в /opt/waypoint/smtp.env — проверяется на сервере (Cloud upload)',
    },
  ];
}

export function countMissingRequired(items: ServiceStatusItem[]): number {
  return items.filter((i) => i.required && !i.ok).length;
}
