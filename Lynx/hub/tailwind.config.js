
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        ink: '#0a0b0d',
        mist: '#c8cdd6',
        lynx: {
          50: '#faf5ff',
          100: '#f3e8ff',
          200: '#e9d5ff',
          300: '#d8b4fe',
          400: '#c084fc',
          500: '#a855f7',
          600: '#9333ea',
          700: '#7e22ce',
          800: '#6b21a8',
          900: '#581c87',
        },
      },
      fontSize: {
        display: ['clamp(2.25rem,5vw,3.75rem)', { lineHeight: '1.08', fontWeight: '700' }],
      },
    },
  },
  plugins: [],
};
