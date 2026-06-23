export type HubNewsPost = {
  slug: string;
  title: string;
  date: string;
  body: string;
};

export type HubEngineCore = {
  id: string;
  label: string;
  version: string;
  note: string;
};

export type HubContent = {
  news: HubNewsPost[];
  engineCores: HubEngineCore[];
};

const STORAGE_KEY = 'lynx-hub-content-override';

export async function loadHubContent(): Promise<HubContent> {
  const { fetchHubContentFromApi } = await import('./hubApi');
  const fromApi = await fetchHubContentFromApi();
  let base: HubContent;
  if (fromApi && (fromApi.news?.length || fromApi.engineCores?.length)) {
    base = fromApi;
  } else {
    const res = await fetch('/content/hub-content.json');
    base = (await res.json()) as HubContent;
  }
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return base;
    const override = JSON.parse(raw) as Partial<HubContent>;
    return {
      news: override.news ?? base.news,
      engineCores: override.engineCores ?? base.engineCores,
    };
  } catch {
    return base;
  }
}

export function saveHubContentOverride(content: HubContent) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(content));
}
