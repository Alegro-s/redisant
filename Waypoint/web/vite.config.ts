import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const favicon = env.VITE_FAVICON || '/favicon.svg';

  return {
  plugins: [
    react(),
    {
      name: 'html-favicon',
      transformIndexHtml(html) {
        return html.replace(/href="\/favicon[^"]*"/g, `href="${favicon}"`);
      },
    },
  ],
  
  define:
    mode === 'production'
      ? {
          'import.meta.env.VITE_API_URL': JSON.stringify('/api'),
          'import.meta.env.VITE_AUTH_URL': JSON.stringify('/auth'),
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
  };
});