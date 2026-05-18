import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const base = env.VITE_BASE || '/';
  const rozaApiTarget = env.VITE_ROZA_API_PROXY || 'http://127.0.0.1:8765';

  return {
    base,
    plugins: [react()],
    server: {
      port: 5180,
      strictPort: true,
      proxy: {
        '/api': { target: rozaApiTarget, changeOrigin: true },
        '/ws': { target: rozaApiTarget, ws: true, changeOrigin: true },
      },
    },
  };
});
