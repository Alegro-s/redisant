import React, { useMemo } from 'react';
import {
  Box,
  Card,
  CardContent,
  Chip,
  Grid,
  Stack,
  Typography,
  alpha,
  Button,
  useTheme,
} from '@mui/material';
import { Link as RouterLink } from 'react-router-dom';
import {
  BUSINESS_SECTIONS,
  DEVELOPER_SECTIONS,
  type WaypointServiceCard,
  type WaypointServiceSection,
} from '../../waypoint/waypointCatalog';
import { WM_CLOUD } from '../../components/layout/cloudShell';

function deliveryLabel(d: WaypointServiceCard['delivery']): string {
  switch (d) {
    case 'console':
      return 'В консоли';
    case 'partial':
      return 'Частично / roadmap';
    case 'manager':
      return 'С менеджером';
    default:
      return '';
  }
}

function ServiceCardView({ c }: { c: WaypointServiceCard }) {
  const theme = useTheme();
  const isDark = theme.palette.mode === 'dark';

  const inner = (
    <Card
      sx={{
        height: '100%',
        borderRadius: 2,
        border: `1px solid ${isDark ? WM_CLOUD.border : theme.palette.divider}`,
        bgcolor: isDark ? alpha(WM_CLOUD.paperElevated, 0.45) : theme.palette.background.paper,
        transition: 'transform 0.2s ease, border-color 0.2s ease',
        '&:hover': {
          transform: 'translateY(-3px)',
          borderColor: alpha(WM_CLOUD.accent, 0.45),
        },
      }}
    >
      <CardContent sx={{ p: 2.25 }}>
        <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1}>
          <Typography variant="subtitle2" sx={{ fontWeight: 700, lineHeight: 1.35 }}>
            {c.title}
          </Typography>
          <Stack direction="row" spacing={0.5} flexShrink={0}>
            {c.badge === 'NEW' && <Chip label="NEW" size="small" color="success" variant="outlined" />}
            {c.badge === 'SOON' && <Chip label="SOON" size="small" variant="outlined" />}
          </Stack>
        </Stack>
        <Typography variant="body2" color="text.secondary" sx={{ mt: 1, lineHeight: 1.55 }}>
          {c.description}
        </Typography>
        <Stack direction="row" flexWrap="wrap" gap={0.5} sx={{ mt: 1.25 }}>
          <Chip size="small" label={deliveryLabel(c.delivery)} variant="outlined" />
          {c.ingestChannel && (
            <Chip size="small" label={`ingest: ${c.ingestChannel}`} sx={{ fontFamily: 'monospace' }} />
          )}
        </Stack>
        {c.href && c.delivery !== 'console' && (
          <Button component={RouterLink} to={c.href} size="small" sx={{ mt: 1.5 }}>
            Открыть
          </Button>
        )}
        {c.href && c.delivery === 'console' && (
          <Typography variant="caption" color="primary" sx={{ mt: 1.5, display: 'block', fontWeight: 600 }}>
            Нажмите на карточку →
          </Typography>
        )}
      </CardContent>
    </Card>
  );

  if (c.href && c.delivery === 'console') {
    return (
      <Box component={RouterLink} to={c.href} sx={{ textDecoration: 'none', color: 'inherit', height: '100%' }}>
        {inner}
      </Box>
    );
  }
  return inner;
}

function SectionBlock({ section }: { section: WaypointServiceSection }) {
  return (
    <Box sx={{ mb: 4 }}>
      <Typography
        variant="h6"
        sx={{
          fontWeight: 800,
          mb: 2,
          letterSpacing: '-0.01em',
        }}
      >
        {section.label}
      </Typography>
      <Grid container spacing={2}>
        {section.cards.map((c) => (
          <Grid item xs={12} sm={6} lg={4} key={c.title}>
            <ServiceCardView c={c} />
          </Grid>
        ))}
      </Grid>
    </Box>
  );
}

export const WaypointBusinessCatalogPage: React.FC = () => {
  return (
    <Box>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 3, maxWidth: 800, lineHeight: 1.65 }}>
        Услуги и направления в духе digital-агентства: от performance и SEO до ORM, аналитики и продакшна. То, что
        автоматизируется в продукте, помечено «В консоли» или «Частично»; полный цикл с командой — «С менеджером».
      </Typography>
      {BUSINESS_SECTIONS.map((s) => (
        <SectionBlock key={s.id} section={s} />
      ))}
    </Box>
  );
};

export const WaypointDevelopersCatalogPage: React.FC = () => {
  const theme = useTheme();
  const legend = useMemo(
    () => [
      { k: 'В консоли', v: 'Уже есть в этой админке или через API.' },
      { k: 'Частично / roadmap', v: 'MVP или в планах масштабирования.' },
      { k: 'С менеджером', v: 'Выделенные ресурсы, договор, не self-service.' },
    ],
    [],
  );

  return (
    <Box>
      <Typography variant="body1" color="text.secondary" sx={{ mb: 2, maxWidth: 800, lineHeight: 1.65 }}>
        Карта в духе облачной панели: проекты, БД, S3, сети, баланс, API. Связка с Lynx Cloud и ядром движка Lynx.
      </Typography>
      <Stack spacing={1} sx={{ mb: 3, p: 2, borderRadius: 2, bgcolor: alpha(theme.palette.info.main, 0.06) }}>
        {legend.map((x) => (
          <Typography key={x.k} variant="body2">
            <strong>{x.k}</strong> — {x.v}
          </Typography>
        ))}
      </Stack>
      {DEVELOPER_SECTIONS.map((s) => (
        <SectionBlock key={s.id} section={s} />
      ))}
    </Box>
  );
};
