import React, { useMemo, useState } from 'react';
import { InputBase, List, ListItemButton, ListItemText, Paper, Popper, ClickAwayListener } from '@mui/material';
import { Search } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';

const ROUTES: { label: string; path: string; keywords: string }[] = [
  { label: 'Дашборд', path: '/dashboard', keywords: 'главная hub' },
  { label: 'Ingest Lab', path: '/dashboard/ingest-lab', keywords: 'метрики логи ingest' },
  { label: 'BaaS SQL', path: '/dashboard/baas/sql', keywords: 'база sql postgres' },
  { label: 'Desktop hosts', path: '/dashboard/desktop-hosts', keywords: 'desktop хосты пк' },
  { label: 'Подключённые устройства', path: '/settings/devices', keywords: 'desktop pair привязка' },
  { label: 'Биллинг', path: '/billing', keywords: 'тариф оплата' },
  { label: 'Документация', path: '/docs', keywords: 'docs справка' },
  { label: 'Настройки', path: '/settings', keywords: 'settings профиль' },
];

export const GlobalSearch: React.FC = () => {
  const [q, setQ] = useState('');
  const [open, setOpen] = useState(false);
  const navigate = useNavigate();
  const anchorRef = React.useRef<HTMLDivElement>(null);

  const hits = useMemo(() => {
    const s = q.trim().toLowerCase();
    if (s.length < 1) return [];
    return ROUTES.filter(
      (r) => r.label.toLowerCase().includes(s) || r.keywords.includes(s) || r.path.includes(s),
    ).slice(0, 8);
  }, [q]);

  return (
    <ClickAwayListener onClickAway={() => setOpen(false)}>
      <div ref={anchorRef} style={{ position: 'relative', flex: 1 }}>
        <Search sx={{ color: 'text.secondary', mr: 1, fontSize: 20 }} />
        <InputBase
          placeholder="Поиск разделов…"
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          sx={{ color: 'text.primary', flex: 1, fontSize: '0.875rem' }}
        />
        <Popper open={open && hits.length > 0} anchorEl={anchorRef.current} placement="bottom-start" style={{ zIndex: 1300 }}>
          <Paper elevation={8} sx={{ mt: 0.5, minWidth: 280 }}>
            <List dense>
              {hits.map((h) => (
                <ListItemButton
                  key={h.path}
                  onClick={() => {
                    navigate(h.path);
                    setOpen(false);
                    setQ('');
                  }}
                >
                  <ListItemText primary={h.label} secondary={h.path} />
                </ListItemButton>
              ))}
            </List>
          </Paper>
        </Popper>
      </div>
    </ClickAwayListener>
  );
};
