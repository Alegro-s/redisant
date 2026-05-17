import axios from 'axios';
import { resolveApiBase } from '../utils/apiBase';

const API_URL = resolveApiBase();

const api = axios.create({
  baseURL: API_URL,
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
    
    'X-Client-Realm': 'metric',
  },
});

api.interceptors.request.use((config) => config);

api.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error.response?.status;
    const url = String(error.config?.url ?? '');
    const authAttempt =
      url.includes('/login') ||
      url.includes('/register') ||
      url.includes('/auth/register/verify') ||
      url.includes('/auth/register/resend') ||
      url.includes('/admin/register') ||
      url.includes('/auth/login') ||
      url.includes('/auth/challenge');
    if (status === 401 && !authAttempt) {
      const path = typeof window !== 'undefined' ? window.location.pathname : '';
      if (path.startsWith('/dashboard')) {
        window.location.href = '/login';
      }
    }
    return Promise.reject(error);
  }
);

export default api;