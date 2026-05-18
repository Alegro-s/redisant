export type CloudConfig = {
  cloudUrl: string;
  authUrl: string;
  apiUrl: string;
  email: string;
  accessToken: string;
  refreshToken: string;
  apiKey: string;
  syncTelemetry: boolean;
  syncTasks: boolean;
  syncProjects: boolean;
  lizaEndpoint: string;
  deviceId: string;
  deviceName: string;
};

/** Из URL Metric выводим auth/api (прод: /auth и /api; локально — отдельные порты). */
export function resolveCloudUrls(cloudUrl: string): Pick<CloudConfig, 'cloudUrl' | 'authUrl' | 'apiUrl'> {
  const cloud = cloudUrl.replace(/\/$/, '').replace(/\/desktop\/?$/, '');
  if (/127\.0\.0\.1:3002|localhost:3002/.test(cloud)) {
    return {
      cloudUrl: cloud,
      authUrl: import.meta.env.VITE_WAYPOINT_AUTH_URL || 'http://127.0.0.1:8090',
      apiUrl: import.meta.env.VITE_WAYPOINT_API_URL || 'http://127.0.0.1:8080',
    };
  }
  return {
    cloudUrl: cloud,
    authUrl: `${cloud}/auth`,
    apiUrl: `${cloud}/api`,
  };
}

export const defaultConfig = (): CloudConfig => {
  const urls = resolveCloudUrls(
    import.meta.env.VITE_WAYPOINT_CLOUD_URL || 'https://metrika-waypoint.ru',
  );
  return {
  ...urls,
  email: '',
  accessToken: '',
  refreshToken: '',
  apiKey: '',
  syncTelemetry: true,
  syncTasks: false,
  syncProjects: false,
  lizaEndpoint: 'http://127.0.0.1:11434',
  deviceId: '',
  deviceName: typeof navigator !== 'undefined' ? `${navigator.platform}-pc` : 'desktop',
};
};
