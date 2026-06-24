/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  async headers() {
    return [
      {
        source: '/_next/static/:path*',
        headers: [{ key: 'Cache-Control', value: 'public, max-age=31536000, immutable' }],
      },
      {
        source: '/:path*',
        headers: [{ key: 'Cache-Control', value: 'no-cache, must-revalidate' }],
      },
    ];
  },
  async redirects() {
    const legacy = ['projects', 'engine', 'builds', 'commercial', 'developer'];
    return legacy.map((path) => ({
      source: `/${path}`,
      destination: '/',
      permanent: false,
    }));
  },
};

export default nextConfig;
