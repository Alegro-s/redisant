import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

const rozaApiTarget = process.env.VITE_ROZA_API_PROXY ?? 'http://127.0.0.1:8765';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5180,
    strictPort: true,
    proxy: {
      '/api': { target: rozaApiTarget, changeOrigin: true },
      '/ws': { target: rozaApiTarget, ws: true, changeOrigin: true },
    },
  },
});
