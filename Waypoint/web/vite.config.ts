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
        let out = html.replace(/href="\/favicon[^"]*"/g, `href="${favicon}"`);
        if (out.includes('apple-touch-icon')) {
          out = out.replace(/rel="apple-touch-icon" href="[^"]*"/, `rel="apple-touch-icon" href="${favicon}"`);
        } else {
          out = out.replace('</head>', `    <link rel="apple-touch-icon" href="${favicon}" />\n  </head>`);
        }
        return out;
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