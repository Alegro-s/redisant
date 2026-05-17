import React from 'react';
import {
  Box,
  Card,
  CardActionArea,
  CardContent,
  Grid,
  Stack,
  Typography,
  alpha,
  useTheme,
} from '@mui/material';
import { Api, Hub, Science, SmartToy, Source, Storage, Cable, QueryStats, Terminal } from '@mui/icons-material';
import { useNavigate } from 'react-router-dom';
import { WM_CLOUD } from '../../components/layout/cloudShell';

const CARDS = [
  {
    to: '/dashboard/developer/ai',
    title: 'AI Copilot',
    body: 'Код, ревью, алгоритмы. Модель по умолчанию — ориентирована на разработку.',
    icon: <SmartToy color="primary" />,
  },
  { to: '/dashboard/lynx-cloud', title: 'Lynx Cloud', body: 'Проекты, сборки, ядро.', icon: <Hub color="primary" />, server: true },
  { to: '/dashboard/projects', title: 'Проекты', body: 'Репозитории и задачи.', icon: <Source color="primary" /> },
  { to: '/dashboard/database', title: 'PostgreSQL', body: 'Запросы и схемы.', icon: <Storage color="primary" />, server: true },
  { to: '/dashboard/baas', title: 'BaaS', body: 'SQL, REST, storage.', icon: <Api color="primary" />, server: true },
  { to: '/dashboard/api', title: 'API агента', body: 'Ключи и вызовы.', icon: <Cable color="primary" />, server: true },
  { to: '/dashboard/module-testing', title: 'Тестирование', body: 'Модули и сравнение алгоритмов.', icon: <Science color="primary" />, server: true },
  { to: '/dashboard/ingest-lab', title: 'Ingest / метрики сервера', body: 'События и симуляция.', icon: <QueryStats color="primary" /> },
];

export const DeveloperHomePage: React.FC = () => {
  const theme = useTheme();
  const navigate = useNavigate();
  const isDark = theme.palette.mode === 'dark';

  return (
    <Stack spacing={3}>
      <Box
        sx={{
          borderRadius: 3,
          p: { xs: 2.25, sm: 3 },
          border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
          background: isDark
            ? `linear-gradient(125deg, ${alpha(WM_CLOUD.paperElevated, 0.9)} 0%, ${alpha('#2d3a4f', 0.85)} 100%)`
            : `linear-gradient(125deg, ${theme.palette.background.paper} 0%, ${alpha(theme.palette.info.main, 0.06)} 100%)`,
        }}
      >
        <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
          <Terminal color="primary" />
          <Typography variant="overline" sx={{ fontWeight: 700, letterSpacing: '0.12em' }}>
            Кабинет · разработка
          </Typography>
        </Stack>
        <Typography variant="h4" sx={{ fontWeight: 800, letterSpacing: '-0.02em', fontSize: { xs: '1.5rem', sm: '2rem' } }}>
          СУБД, BaaS, ingest и облако — слой данных и автоматизации рядом с продуктом
        </Typography>
        <Typography variant="body1" color="text.secondary" sx={{ mt: 1.25, maxWidth: 800, lineHeight: 1.7 }}>
          Здесь не про сцену и спрайты: PostgreSQL, SQL/REST, тесты модулей, Lynx Cloud и Copilot помогают выкатывать сервисы.
          Метрики и бизнес-сценарии переключаются в режим «Бизнес». Пункты с пометкой «сервер» активны после аренды или своего API.
        </Typography>
      </Box>

      <Grid container spacing={2}>
        {CARDS.map((c) => (
          <Grid item xs={12} sm={6} md={4} key={c.to}>
            <Card
              sx={{
                borderRadius: 3,
                height: '100%',
                border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
                bgcolor: isDark ? alpha(WM_CLOUD.paperElevated, 0.4) : theme.palette.background.paper,
              }}
            >
              <CardActionArea onClick={() => navigate(c.to)} sx={{ height: '100%' }}>
                <CardContent sx={{ p: 2.25 }}>
                  <Stack direction="row" spacing={1.25} alignItems="flex-start">
                    <Box sx={{ mt: 0.25 }}>{c.icon}</Box>
                    <Box>
                      <Typography variant="subtitle1" fontWeight={700}>
                        {c.title}
                        {c.server && (
                          <Typography component="span" variant="caption" color="text.secondary" sx={{ ml: 0.75 }}>
                            · сервер
                          </Typography>
                        )}
                      </Typography>
                      <Typography variant="body2" color="text.secondary" sx={{ mt: 0.75, lineHeight: 1.55 }}>
                        {c.body}
                      </Typography>
                    </Box>
                  </Stack>
                </CardContent>
              </CardActionArea>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Stack>
  );
};
