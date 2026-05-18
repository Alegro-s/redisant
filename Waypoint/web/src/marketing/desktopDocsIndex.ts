import { DESKTOP_DOCS, DESKTOP_DOC_NAV, type DesktopDocTopic } from './desktopDocsContent';

export type DesktopDocSearchHit = {
  topic: DesktopDocTopic;
  label: string;
  section: string;
  snippet: string;
};

export function searchDesktopDocs(query: string): DesktopDocSearchHit[] {
  const q = query.trim().toLowerCase();
  if (q.length < 2) return [];
  const hits: DesktopDocSearchHit[] = [];
  for (const item of DESKTOP_DOC_NAV) {
    const doc = DESKTOP_DOCS[item.topic];
    if (doc.title.toLowerCase().includes(q) || doc.subtitle.toLowerCase().includes(q)) {
      hits.push({
        topic: item.topic,
        label: item.label,
        section: doc.title,
        snippet: doc.subtitle,
      });
    }
    for (const s of doc.sections) {
      if (s.h.toLowerCase().includes(q) || s.p.toLowerCase().includes(q)) {
        hits.push({
          topic: item.topic,
          label: item.label,
          section: s.h,
          snippet: s.p.slice(0, 120) + (s.p.length > 120 ? '…' : ''),
        });
      }
    }
  }
  return hits.slice(0, 12);
}
