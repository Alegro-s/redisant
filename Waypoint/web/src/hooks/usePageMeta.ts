import { useEffect } from 'react';

export type PageMeta = {
  title: string;
  description?: string;
  ogImage?: string;
  themeColor?: string;
};

function upsertMeta(attr: 'name' | 'property', key: string, content: string) {
  let el = document.querySelector(`meta[${attr}="${key}"]`) as HTMLMetaElement | null;
  if (!el) {
    el = document.createElement('meta');
    el.setAttribute(attr, key);
    document.head.appendChild(el);
  }
  el.content = content;
}

export function usePageMeta(meta: PageMeta) {
  useEffect(() => {
    const prevTitle = document.title;
    document.title = meta.title;
    if (meta.description) {
      upsertMeta('name', 'description', meta.description);
      upsertMeta('property', 'og:description', meta.description);
    }
    upsertMeta('property', 'og:title', meta.title);
    upsertMeta('property', 'og:type', 'website');
    if (meta.ogImage) upsertMeta('property', 'og:image', meta.ogImage);
    if (meta.themeColor) {
      upsertMeta('name', 'theme-color', meta.themeColor);
    }
    return () => {
      document.title = prevTitle;
    };
  }, [meta.title, meta.description, meta.ogImage, meta.themeColor]);
}
