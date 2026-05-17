import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

const authTarget = process.env.VITE_AUTH_API_PROXY ?? 'http://127.0.0.1:8090';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5175,
    proxy: {
      '/auth': { target: authTarget, changeOrigin: true, rewrite: (p) => p.replace(/^\/auth/, '') },
    },
  },
});
