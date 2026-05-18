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

export const defaultConfig = (): CloudConfig => ({
  cloudUrl: (import.meta.env.VITE_WAYPOINT_CLOUD_URL || 'http://127.0.0.1:3002').replace(/\/desktop\/?$/, ''),
  authUrl: import.meta.env.VITE_WAYPOINT_AUTH_URL || 'http://127.0.0.1:8090',
  apiUrl: import.meta.env.VITE_WAYPOINT_API_URL || 'http://127.0.0.1:8080',
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
});
