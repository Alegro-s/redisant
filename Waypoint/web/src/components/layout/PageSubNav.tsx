import React from 'react';
import { Box, Link } from '@mui/material';
import { Link as RouterLink, useLocation } from 'react-router-dom';
import { WM_CLOUD } from './cloudShell';

export type PageSubNavItem = {
  label: string;
  to: string;
  end?: boolean;
};

type PageSubNavProps = {
  items: PageSubNavItem[];
};


export const PageSubNav: React.FC<PageSubNavProps> = ({ items }) => {
  const { pathname } = useLocation();

  return (
    <Box
      sx={{
        display: 'flex',
        flexWrap: 'wrap',
        gap: 0.5,
        mb: 2.5,
        pb: 0,
        borderBottom: (t) => `1px solid ${t.palette.divider}`,
        mx: { xs: -0.5, sm: 0 },
      }}
    >
      {items.map((item) => {
        const end = item.end ?? false;
        const active = end
          ? pathname === item.to || (item.to === '/dashboard/overview' && pathname === '/dashboard')
          : pathname === item.to || pathname.startsWith(`${item.to}/`);
        return (
          <Link
            key={item.to}
            component={RouterLink}
            to={item.to}
            underline="none"
            sx={{
              px: 1.5,
              py: 1,
              mr: 0.5,
              mb: '-1px',
              borderBottom: '2px solid',
              borderColor: active ? 'primary.main' : 'transparent',
              color: active ? 'text.primary' : 'text.secondary',
              fontWeight: active ? 700 : 500,
              fontSize: '0.875rem',
              borderRadius: '8px 8px 0 0',
              '&:hover': {
                color: 'text.primary',
                bgcolor: (t) => (t.palette.mode === 'dark' ? WM_CLOUD.accentMuted : t.palette.action.hover),
              },
            }}
          >
            {item.label}
          </Link>
        );
      })}
    </Box>
  );
};
