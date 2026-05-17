import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => ({
  plugins: [react()],
  
  define:
    mode === 'production'
      ? {
          'import.meta.env.VITE_API_URL': JSON.stringify('/api'),
        }
      : {},
  server: {
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8080',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '') || '/',
      },
      '/auth': {
        target: 'http://127.0.0.1:8090',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/auth/, '') || '/',
      },
      '/ws': {
        target: 'ws://localhost:8082',
        ws: true,
      },
      '/roza': {
        target: 'http://127.0.0.1:5180',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/roza/, '') || '/',
      },
    },
  },
}));