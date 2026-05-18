import { Link, useParams } from 'react-router-dom';
import { Box, Typography } from '@mui/material';
import { usePageMeta } from '../hooks/usePageMeta';
import { LINKS, desktopDocsUrl } from './links';
import { METRIC_DOCS, METRIC_DOC_NAV, type MetricDocTopic } from './metricDocsContent';

const VALID = new Set<string>(Object.keys(METRIC_DOCS));

export function MetricDocsPage() {
  const { topic } = useParams<{ topic?: string }>();
  const active: MetricDocTopic =
    topic && VALID.has(topic) ? (topic as MetricDocTopic) : 'start';
  const doc = METRIC_DOCS[active];

  usePageMeta({
    title: `${doc.title} — документация`,
    description: doc.subtitle,
    themeColor: '#34B67A',
  });

  return (
    <Box sx={{ minHeight: '100vh', bgcolor: '#0a0f0d', color: '#e8f5ef', px: { xs: 2, md: 4 }, py: 4 }}>
      <Box sx={{ maxWidth: 960, mx: 'auto' }}>
        <Box sx={{ display: 'flex', gap: 2, flexWrap: 'wrap', mb: 3 }}>
          <Typography component={Link} to="/" sx={{ color: '#34B67A', textDecoration: 'none', fontWeight: 700 }}>
            ← Waypoint Metric
          </Typography>
          <Typography component="a" href={desktopDocsUrl()} sx={{ color: '#7dd3a8', ml: 'auto' }}>
            Документация Desktop →
          </Typography>
        </Box>
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', md: '200px 1fr' }, gap: 3 }}>
          <nav>
            {METRIC_DOC_NAV.map((item) => (
              <Typography
                key={item.topic}
                component={Link}
                to={item.topic === 'start' ? '/metric/docs' : `/metric/docs/${item.topic}`}
                sx={{
                  display: 'block',
                  py: 0.75,
                  px: 1,
                  borderRadius: 1,
                  color: item.topic === active ? '#34B67A' : '#8fa89a',
                  fontWeight: item.topic === active ? 700 : 400,
                  textDecoration: 'none',
                }}
              >
                {item.label}
              </Typography>
            ))}
          </nav>
          <article>
            <Typography variant="h4" gutterBottom>
              {doc.title}
            </Typography>
            <Typography sx={{ color: '#8fa89a', mb: 3 }}>{doc.subtitle}</Typography>
            {doc.sections.map((s) => (
              <Box key={s.h} sx={{ mb: 2.5 }}>
                <Typography variant="h6" sx={{ color: '#34B67A' }}>
                  {s.h}
                </Typography>
                <Typography sx={{ color: '#b8d4c8', lineHeight: 1.65 }}>{s.p}</Typography>
              </Box>
            ))}
            {active === 'desktop' && (
              <Typography sx={{ mt: 2 }}>
                <a href={desktopDocsUrl('cloud')} style={{ color: '#34B67A' }}>
                  Подробнее на сайте Desktop
                </a>
              </Typography>
            )}
          </article>
        </Box>
        <Typography sx={{ mt: 4, fontSize: '0.85rem', color: '#6a8a7a' }}>
          © Waypoint Metric · <a href={LINKS.club}>Club</a>
        </Typography>
      </Box>
    </Box>
  );
}
