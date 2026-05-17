/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
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
