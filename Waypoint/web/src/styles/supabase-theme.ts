import { createTheme, alpha } from '@mui/material/styles';
import { WM_CLOUD } from '../components/layout/cloudShell';

const P = WM_CLOUD.accent;

export const supabaseDarkTheme = createTheme({
  palette: {
    mode: 'dark',
    primary: {
      main: P,
      light: '#4BC48A',
      dark: '#278E5F',
      contrastText: '#FFFFFF',
    },
    secondary: {
      main: '#475569',
      light: '#64748B',
      dark: '#334155',
      contrastText: '#FFFFFF',
    },
    error: {
      main: '#F43F5E',
      light: '#FB7185',
      dark: '#E11D48',
    },
    warning: {
      main: '#F59E0B',
      light: '#FBBF24',
      dark: '#D97706',
    },
    info: {
      main: '#3B82F6',
      light: '#60A5FA',
      dark: '#2563EB',
    },
    success: {
      main: '#10B981',
      light: '#34D399',
      dark: '#059669',
    },
    background: {
      default: WM_CLOUD.canvas,
      paper: WM_CLOUD.paperElevated,
    },
    text: {
      primary: '#E7EEF7',
      secondary: '#7F91A4',
      disabled: '#5C6B7A',
    },
    divider: 'rgba(255, 255, 255, 0.08)',
    grey: {
      50: '#FAFAFA',
      100: '#F5F5F5',
      200: '#E5E5E5',
      300: '#D4D4D4',
      400: '#A3A3A3',
      500: '#737373',
      600: '#525252',
      700: '#404040',
      800: '#262626',
      900: '#171717',
    },
  },
  shape: {
    borderRadius: 12,
  },
  typography: {
    fontFamily: '"Inter", "SF Pro Display", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    h1: { fontWeight: 700, letterSpacing: '-0.02em' },
    h2: { fontWeight: 700, letterSpacing: '-0.02em' },
    h3: { fontWeight: 600, letterSpacing: '-0.01em' },
    h4: { fontWeight: 600, letterSpacing: '-0.01em', fontSize: '1.75rem' },
    h5: { fontWeight: 600, fontSize: '1.25rem' },
    h6: { fontWeight: 600, fontSize: '1rem' },
    body1: { fontSize: '0.875rem', lineHeight: 1.6 },
    body2: { fontSize: '0.75rem', lineHeight: 1.6 },
    button: { textTransform: 'none', fontWeight: 500 },
    caption: { fontSize: '0.75rem', color: '#A1A1A1' },
  },
  components: {
    MuiCssBaseline: {
      styleOverrides: {
        body: {
          scrollbarWidth: 'thin',
          '&::-webkit-scrollbar': { width: 8, height: 8 },
          '&::-webkit-scrollbar-track': { background: WM_CLOUD.sidebarPanel },
          '&::-webkit-scrollbar-thumb': {
            background: 'rgba(255,255,255,0.12)',
            borderRadius: 8,
            '&:hover': { background: 'rgba(255,255,255,0.18)' },
          },
        },
      },
    },
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: 16,
          border: `1px solid ${WM_CLOUD.border}`,
          background: alpha(P, 0.03),
          transition: 'border-color 0.2s ease, box-shadow 0.2s ease',
          '&:hover': {
            borderColor: alpha(P, 0.22),
            boxShadow: '0 8px 32px rgba(0,0,0,0.35)',
          },
        },
      },
    },
    MuiPaper: {
      styleOverrides: {
        root: {
          backgroundImage: 'none',
          borderRadius: 16,
          border: `1px solid ${WM_CLOUD.border}`,
          backgroundColor: WM_CLOUD.paperElevated,
        },
      },
    },
    MuiButton: {
      styleOverrides: {
        root: {
          borderRadius: 10,
          textTransform: 'none',
          fontWeight: 500,
          padding: '8px 16px',
          fontSize: '0.875rem',
        },
        contained: {
          backgroundColor: P,
          transition: 'background-color 0.2s ease, box-shadow 0.2s ease',
          border: '1px solid rgba(52, 182, 122, 0.55)',
          '&:hover': {
            backgroundColor: WM_CLOUD.accentHover,
            border: '1px solid rgba(52, 182, 122, 0.78)',
            boxShadow: '0 4px 14px rgba(52, 182, 122, 0.28)',
          },
        },
        outlined: {
          borderColor: 'rgba(255,255,255,0.12)',
          '&:hover': {
            borderColor: P,
            background: alpha(P, 0.06),
          },
        },
      },
    },
    MuiDrawer: {
      styleOverrides: {
        paper: {
          backgroundColor: WM_CLOUD.sidebarPanel,
          borderRight: `1px solid ${WM_CLOUD.border}`,
        },
      },
    },
    MuiListItemButton: {
      styleOverrides: {
        root: {
          borderRadius: 10,
          margin: '4px 8px',
          '&.Mui-selected': {
            backgroundColor: alpha(P, 0.12),
            '&:hover': {
              backgroundColor: alpha(P, 0.18),
            },
          },
          '&:hover': {
            backgroundColor: alpha(P, 0.06),
          },
        },
      },
    },
    MuiTableContainer: {
      styleOverrides: {
        root: {
          borderRadius: 16,
          border: `1px solid ${WM_CLOUD.border}`,
          backgroundColor: alpha(WM_CLOUD.canvas, 0.5),
        },
      },
    },
    MuiTableHead: {
      styleOverrides: {
        root: {
          '& .MuiTableRow-root': {
            height: 46,
          },
        },
      },
    },
    MuiTableRow: {
      styleOverrides: {
        root: {
          '&:last-child td, &:last-child th': {
            borderBottom: 0,
          },
          '&.MuiTableRow-hover:hover': {
            backgroundColor: alpha(P, 0.06),
          },
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: {
          borderBottom: `1px solid ${WM_CLOUD.border}`,
          padding: '12px 14px',
          fontSize: '0.84rem',
        },
        head: {
          backgroundColor: alpha(P, 0.08),
          fontWeight: 600,
          color: alpha('#E7EEF7', 0.95),
          letterSpacing: '0.02em',
          textTransform: 'uppercase',
          fontSize: '0.71rem',
        },
      },
    },
    MuiTableSortLabel: {
      styleOverrides: {
        root: {
          '&:hover': {
            color: '#EDEDED',
          },
          '&.Mui-active': {
            color: P,
          },
        },
        icon: {
          color: `${P} !important`,
        },
      },
    },
    MuiTablePagination: {
      styleOverrides: {
        root: {
          backgroundColor: alpha(WM_CLOUD.canvas, 0.35),
        },
        toolbar: {
          minHeight: 50,
        },
        selectIcon: {
          color: '#A1A1A1',
        },
      },
    },
    MuiChip: {
      styleOverrides: {
        root: {
          borderRadius: 8,
          fontWeight: 500,
          fontSize: '0.75rem',
        },
      },
    },
    MuiTextField: {
      styleOverrides: {
        root: {
          '& .MuiOutlinedInput-root': {
            borderRadius: 10,
            '& fieldset': {
              borderColor: 'rgba(255,255,255,0.1)',
            },
            '&:hover fieldset': {
              borderColor: P,
            },
          },
        },
      },
    },
    MuiAlert: {
      styleOverrides: {
        root: {
          borderRadius: 12,
        },
      },
    },
    MuiDialog: {
      styleOverrides: {
        paper: {
          borderRadius: 20,
          backgroundColor: WM_CLOUD.paperElevated,
        },
      },
    },
    MuiAppBar: {
      styleOverrides: {
        root: {
          backgroundColor: WM_CLOUD.header,
          backdropFilter: 'blur(12px)',
        },
      },
    },
  },
});

export const supabaseLightTheme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#34B67A',
      light: '#4BC48A',
      dark: '#278E5F',
    },
    secondary: {
      main: '#475569',
      light: '#64748B',
      dark: '#334155',
    },
    background: {
      default: '#F8FAFC',
      paper: '#FFFFFF',
    },
    text: {
      primary: '#0F172A',
      secondary: '#475569',
      disabled: '#94A3B8',
    },
    divider: '#E2E8F0',
  },
  shape: {
    borderRadius: 12,
  },
  typography: {
    fontFamily: '"Inter", "SF Pro Display", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  },
  components: {
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: 16,
          border: '1px solid #E2E8F0',
          transition: 'all 0.2s ease',
          '&:hover': {
            boxShadow: '0 8px 32px rgba(0,0,0,0.1)',
          },
        },
      },
    },
    MuiButton: {
      styleOverrides: {
        root: {
          borderRadius: 10,
          textTransform: 'none',
        },
        contained: {
          backgroundColor: '#34B67A',
          transition: 'background-color 0.2s ease, box-shadow 0.2s ease',
          border: '1px solid rgba(52, 182, 122, 0.62)',
          '&:hover': {
            backgroundColor: '#2D9E6C',
            border: '1px solid rgba(52, 182, 122, 0.78)',
            boxShadow: '0 4px 14px rgba(52, 182, 122, 0.24)',
          },
        },
      },
    },
    MuiTableContainer: {
      styleOverrides: {
        root: {
          borderRadius: 16,
          border: '1px solid #E2E8F0',
          backgroundColor: '#FFFFFF',
        },
      },
    },
    MuiTableHead: {
      styleOverrides: {
        root: {
          '& .MuiTableRow-root': {
            height: 44,
          },
        },
      },
    },
    MuiTableRow: {
      styleOverrides: {
        root: {
          '&.MuiTableRow-hover:hover': {
            backgroundColor: alpha('#34B67A', 0.06),
          },
        },
      },
    },
    MuiTableCell: {
      styleOverrides: {
        root: {
          borderBottom: '1px solid #E2E8F0',
          padding: '11px 14px',
          fontSize: '0.84rem',
        },
        head: {
          backgroundColor: alpha('#34B67A', 0.08),
          color: '#0F172A',
          fontWeight: 600,
          letterSpacing: '0.02em',
          textTransform: 'uppercase',
          fontSize: '0.71rem',
        },
      },
    },
    MuiTableSortLabel: {
      styleOverrides: {
        root: {
          '&.Mui-active': {
            color: '#278E5F',
          },
        },
        icon: {
          color: '#278E5F !important',
        },
      },
    },
    MuiTablePagination: {
      styleOverrides: {
        root: {
          borderTop: '1px solid #E2E8F0',
        },
        toolbar: {
          minHeight: 50,
        },
      },
    },
  },
});