import React, { useMemo, useState } from 'react';
import { InputBase, List, ListItemButton, ListItemText, Paper, Popper, ClickAwayListener } from '@mui/material';
import { Search } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';

const ROUTES: { label: string; path: string; keywords: string }[] = [
  { label: 'Рабочий стол', path: '/dashboard', keywords: 'главная hub' },
  { label: 'Обзор', path: '/dashboard/overview', keywords: 'дашборд графики' },
  { label: 'Метрики', path: '/dashboard/ingest-lab/summary', keywords: 'сводка события' },
  { label: 'База данных', path: '/dashboard/database', keywords: 'sql таблицы er postgres baas' },
  { label: 'SQL-терминал', path: '/dashboard/database/sql', keywords: 'запрос sql' },
  { label: 'Ключи базы', path: '/dashboard/database/api', keywords: 'ключ подключение' },
  { label: 'Waypoint Desktop', path: '/dashboard/settings/devices', keywords: 'привязка pair устройства пк' },
  { label: 'Помощник', path: '/dashboard/business/ai', keywords: 'ai чат' },
  { label: 'Подключение', path: '/dashboard/connect', keywords: 'ключ приложение' },
  { label: 'Настройки', path: '/dashboard/settings', keywords: 'профиль' },
  { label: 'Биллинг', path: '/dashboard/billing', keywords: 'тариф оплата' },
  { label: 'Lynx Cloud', path: '/dashboard/lynx-cloud', keywords: 'облако проекты' },
  { label: 'Документация', path: '/metric/docs', keywords: 'docs справка' },
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
      <div ref={anchorRef} style={{ position: 'relative', flex: 1, display: 'flex', alignItems: 'center' }}>
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
