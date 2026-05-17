import React, { useState } from 'react';
import { Box, Drawer, useMediaQuery, useTheme, alpha } from '@mui/material';
import { Sidebar } from './Sidebar';
import { Header } from './Header';
import { MobileNavigation } from './MobileNavigation';
import { DRAWER_WIDTH as drawerWidth, APP_BAR_HEIGHT } from './layoutConstants';
import { MOBILE_NAV_HEIGHT } from './MobileNavigation';

interface ModernLayoutProps {
  children: React.ReactNode;
}

export const ModernLayout: React.FC<ModernLayoutProps> = ({ children }) => {
  const [mobileOpen, setMobileOpen] = useState(false);
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('sm'));

  const handleDrawerToggle = () => {
    setMobileOpen(!mobileOpen);
  };

  return (
    <Box sx={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', bgcolor: 'background.default' }}>
      <Header onMenuClick={handleDrawerToggle} />

      <Box
        sx={{
          display: 'flex',
          flex: 1,
          mt: `${APP_BAR_HEIGHT}px`,
          minHeight: `calc(100vh - ${APP_BAR_HEIGHT}px)`,
          alignItems: 'stretch',
        }}
      >
        <Box
          component="nav"
          sx={{
            width: { sm: drawerWidth },
            flexShrink: { sm: 0 },
            height: { sm: `calc(100vh - ${APP_BAR_HEIGHT}px)` },
            position: { sm: 'sticky' },
            top: { sm: APP_BAR_HEIGHT },
            alignSelf: { sm: 'flex-start' },
          }}
        >
          <Drawer
            variant="temporary"
            open={mobileOpen}
            onClose={handleDrawerToggle}
            ModalProps={{ keepMounted: true }}
            sx={{
              display: { xs: 'block', sm: 'none' },
              '& .MuiDrawer-paper': {
                width: drawerWidth,
                boxSizing: 'border-box',
                top: APP_BAR_HEIGHT,
                height: `calc(100% - ${APP_BAR_HEIGHT}px)`,
              },
            }}
          >
            <Sidebar onClose={handleDrawerToggle} />
          </Drawer>

          <Drawer
            variant="permanent"
            sx={{
              display: { xs: 'none', sm: 'block' },
              height: '100%',
              '& .MuiDrawer-paper': {
                width: drawerWidth,
                boxSizing: 'border-box',
                position: 'relative',
                height: '100%',
                overflow: 'auto',
                borderRight: (t) => `1px solid ${t.palette.divider}`,
              },
            }}
            open
          >
            <Sidebar />
          </Drawer>
        </Box>

        <Box
          component="main"
          sx={(t) => ({
            flexGrow: 1,
            p: { xs: 'clamp(12px, 3vw, 20px)', sm: 'clamp(16px, 2vw, 28px)', md: 2.5 },
            pb: {
              xs: `calc(${MOBILE_NAV_HEIGHT}px + env(safe-area-inset-bottom, 12px))`,
              sm: 2.5,
            },
            width: { sm: `calc(100% - ${drawerWidth}px)` },
            minWidth: 0,
            bgcolor: 'background.default',
            backgroundImage: `radial-gradient(ellipse 70% 45% at 0% 0%, ${alpha(t.palette.primary.main, 0.06)}, transparent 55%),
              radial-gradient(ellipse 50% 35% at 100% 0%, ${alpha(t.palette.primary.dark, 0.05)}, transparent 50%)`,
          })}
        >
          <Box
            sx={{
              maxWidth: 1320,
              mx: 'auto',
            }}
          >
            {children}
          </Box>
        </Box>
      </Box>

      {isMobile && <MobileNavigation />}
    </Box>
  );
};
