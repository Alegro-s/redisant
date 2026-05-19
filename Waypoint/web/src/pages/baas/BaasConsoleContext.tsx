import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import {
  createBaasEnvironment,
  createBaasTable,
  createBucket,
  deleteBaasEnvironment,
  deleteBaasRow,
  downloadBaasObject,
  fetchBaasBootstrap,
  insertBaasRow,
  listBaasEnvironments,
  listBaasRestRows,
  listBaasTables,
  listBuckets,
  runBaasSql,
  uploadBaasObject,
  type BaasEnvironment,
} from '../../services/baas.service';
import { BAAS_ENV_STORAGE_KEY } from '../../services/api';
import { deepseekChat } from '../../services/waypoint-chat.service';
import { useNotification } from '../../app/hooks/useNotification';
import { isAxiosError } from 'axios';

const RATE_LIMIT_COOLDOWN_MS = 90_000;

export type BaasConsoleContextValue = {
  loading: boolean;
  rateLimited: boolean;
  rateLimitSecondsLeft: number;
  environments: BaasEnvironment[];
  activeEnvironmentId: string | null;
  activeEnvironment: BaasEnvironment | null;
  setActiveEnvironmentId: (id: string) => void;
  createEnvironment: (name: string) => Promise<void>;
  deleteEnvironment: (id: string) => Promise<void>;
  reloadEnvironments: () => Promise<void>;
  schemaName: string | null;
  sql: string;
  setSql: (v: string) => void;
  sqlResult: string;
  tables: string[];
  newTable: string;
  setNewTable: (v: string) => void;
  restTable: string;
  setRestTable: (v: string) => void;
  restRows: Record<string, unknown>[];
  restJson: string;
  setRestJson: (v: string) => void;
  buckets: { id: string; name: string; public_read: boolean }[];
  newBucket: string;
  setNewBucket: (v: string) => void;
  uploadBucket: string;
  setUploadBucket: (v: string) => void;
  objectKey: string;
  setObjectKey: (v: string) => void;
  chatIn: string;
  setChatIn: (v: string) => void;
  chatOut: string;
  loadBaasBootstrap: () => Promise<void>;
  refreshTables: () => Promise<void>;
  refreshBuckets: () => Promise<void>;
  onRunSql: () => Promise<void>;
  onCreateTable: () => Promise<void>;
  onLoadRest: () => Promise<void>;
  onInsertRest: () => Promise<void>;
  onDeleteRow: (id: string) => Promise<void>;
  onCreateBucket: () => Promise<void>;
  onUpload: (e: React.ChangeEvent<HTMLInputElement>) => Promise<void>;
  onDownload: () => Promise<void>;
  onChat: () => Promise<void>;
};

const BaasConsoleContext = createContext<BaasConsoleContextValue | null>(null);

function isRateLimitedError(err: unknown): boolean {
  return isAxiosError(err) && err.response?.status === 429;
}

export const BaasConsoleProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { showError, showSuccess } = useNotification();
  const notifyRef = useRef({ showError, showSuccess });
  notifyRef.current = { showError, showSuccess };

  const bootstrapInFlight = useRef(false);
  const envInFlight = useRef(false);
  const rateLimitUntil = useRef(0);
  const lastRateLimitToast = useRef(0);
  const initStarted = useRef(false);

  const [loading, setLoading] = useState(false);
  const [rateLimitTick, setRateLimitTick] = useState(0);
  const [schemaName, setSchemaName] = useState<string | null>(null);
  const [sql, setSql] = useState('SELECT 1 AS ok');
  const [sqlResult, setSqlResult] = useState<string>('');
  const [tables, setTables] = useState<string[]>([]);
  const [newTable, setNewTable] = useState('items');
  const [restTable, setRestTable] = useState('');
  const [restRows, setRestRows] = useState<Record<string, unknown>[]>([]);
  const [restJson, setRestJson] = useState('{"hello":"world"}');
  const [buckets, setBuckets] = useState<{ id: string; name: string; public_read: boolean }[]>([]);
  const [newBucket, setNewBucket] = useState('default');
  const [uploadBucket, setUploadBucket] = useState('');
  const [objectKey, setObjectKey] = useState('demo.txt');
  const [chatIn, setChatIn] = useState('');
  const [chatOut, setChatOut] = useState('');
  const [environments, setEnvironments] = useState<BaasEnvironment[]>([]);
  const [activeEnvironmentId, setActiveEnvironmentIdState] = useState<string | null>(() => {
    try {
      return localStorage.getItem(BAAS_ENV_STORAGE_KEY);
    } catch {
      return null;
    }
  });

  const rateLimited = rateLimitUntil.current > Date.now();
  const rateLimitSecondsLeft = rateLimited
    ? Math.max(0, Math.ceil((rateLimitUntil.current - Date.now()) / 1000))
    : 0;

  useEffect(() => {
    if (!rateLimited) return;
    const id = window.setInterval(() => setRateLimitTick((t) => t + 1), 1000);
    return () => window.clearInterval(id);
  }, [rateLimited, rateLimitTick]);

  const handleRateLimit = useCallback(() => {
    rateLimitUntil.current = Date.now() + RATE_LIMIT_COOLDOWN_MS;
    setRateLimitTick((t) => t + 1);
    const now = Date.now();
    if (now - lastRateLimitToast.current > 8000) {
      lastRateLimitToast.current = now;
      notifyRef.current.showError(
        'Слишком много запросов. Подождите около минуты и обновите страницу.',
      );
    }
  }, []);

  const activeEnvironment =
    environments.find((e) => e.id === activeEnvironmentId) ??
    environments.find((e) => e.is_default) ??
    environments[0] ??
    null;

  const loadBaasBootstrap = useCallback(async () => {
    if (rateLimitUntil.current > Date.now()) return;
    if (bootstrapInFlight.current) return;
    bootstrapInFlight.current = true;
    setLoading(true);
    try {
      const b = await fetchBaasBootstrap();
      setSchemaName(b.schema_name);
      setTables(b.tables);
      setBuckets(b.buckets);
      setRestTable((prev) => prev || (b.tables[0] ?? ''));
      setUploadBucket((prev) => prev || (b.buckets[0]?.name ?? ''));
    } catch (err) {
      if (isRateLimitedError(err)) {
        handleRateLimit();
      } else {
        notifyRef.current.showError('Не удалось загрузить базу. Проверьте настройку облака.');
      }
      setSchemaName(null);
      setTables([]);
      setBuckets([]);
    } finally {
      bootstrapInFlight.current = false;
      setLoading(false);
    }
  }, [handleRateLimit]);

  const reloadEnvironments = useCallback(async () => {
    if (rateLimitUntil.current > Date.now()) return;
    if (envInFlight.current) return;
    envInFlight.current = true;
    try {
      const list = await listBaasEnvironments();
      setEnvironments(list);
      const stored = localStorage.getItem(BAAS_ENV_STORAGE_KEY);
      const pick =
        (stored && list.some((e) => e.id === stored) ? stored : null) ??
        list.find((e) => e.is_default)?.id ??
        list[0]?.id ??
        null;
      if (pick) {
        setActiveEnvironmentIdState(pick);
        localStorage.setItem(BAAS_ENV_STORAGE_KEY, pick);
      }
    } catch (err) {
      if (isRateLimitedError(err)) {
        handleRateLimit();
      } else {
        notifyRef.current.showError('Не удалось загрузить список подпроектов');
      }
    } finally {
      envInFlight.current = false;
    }
  }, [handleRateLimit]);

  const setActiveEnvironmentId = useCallback((id: string) => {
    setActiveEnvironmentIdState(id);
    try {
      localStorage.setItem(BAAS_ENV_STORAGE_KEY, id);
    } catch {
      void 0;
    }
  }, []);

  useEffect(() => {
    if (initStarted.current) return;
    initStarted.current = true;
    void reloadEnvironments();
  }, [reloadEnvironments]);

  useEffect(() => {
    if (!activeEnvironmentId) return;
    const t = window.setTimeout(() => {
      void loadBaasBootstrap();
    }, 200);
    return () => window.clearTimeout(t);
  }, [activeEnvironmentId, loadBaasBootstrap]);

  const createEnvironment = async (name: string) => {
    setLoading(true);
    try {
      const env = await createBaasEnvironment(name.trim());
      notifyRef.current.showSuccess(`Подпроект «${env.name}» создан`);
      await reloadEnvironments();
      setActiveEnvironmentId(env.id);
      await loadBaasBootstrap();
    } catch (err) {
      if (isRateLimitedError(err)) handleRateLimit();
      else notifyRef.current.showError('Не удалось создать подпроект');
    } finally {
      setLoading(false);
    }
  };

  const deleteEnvironment = async (id: string) => {
    if (!window.confirm('Удалить подпроект и все его данные? Это нельзя отменить.')) return;
    setLoading(true);
    try {
      await deleteBaasEnvironment(id);
      notifyRef.current.showSuccess('Подпроект удалён');
      if (activeEnvironmentId === id) {
        localStorage.removeItem(BAAS_ENV_STORAGE_KEY);
        setActiveEnvironmentIdState(null);
      }
      await reloadEnvironments();
      await loadBaasBootstrap();
    } catch (err) {
      if (isRateLimitedError(err)) handleRateLimit();
      else notifyRef.current.showError('Не удалось удалить подпроект');
    } finally {
      setLoading(false);
    }
  };

  const refreshTables = useCallback(async () => {
    try {
      const t = await listBaasTables();
      setTables(t);
      setRestTable((prev) => prev || (t[0] ?? ''));
    } catch (err) {
      if (isRateLimitedError(err)) handleRateLimit();
      else notifyRef.current.showError('Список таблиц недоступен');
    }
  }, [handleRateLimit]);

  const refreshBuckets = useCallback(async () => {
    try {
      const list = await listBuckets();
      setBuckets(list);
      setUploadBucket((prev) => prev || (list[0]?.name ?? ''));
    } catch (err) {
      if (isRateLimitedError(err)) handleRateLimit();
      else notifyRef.current.showError('Список файлов недоступен');
    }
  }, [handleRateLimit]);

  const onRunSql = async () => {
    setLoading(true);
    setSqlResult('');
    try {
      const r = await runBaasSql(sql);
      setSqlResult(JSON.stringify(r, null, 2));
    } catch {
      notifyRef.current.showError('Не удалось выполнить запрос');
    } finally {
      setLoading(false);
    }
  };

  const onCreateTable = async () => {
    setLoading(true);
    try {
      await createBaasTable(newTable.trim());
      notifyRef.current.showSuccess('Таблица создана');
      await refreshTables();
    } catch {
      notifyRef.current.showError('Не удалось создать таблицу');
    } finally {
      setLoading(false);
    }
  };

  const onLoadRest = async () => {
    if (!restTable) return;
    setLoading(true);
    try {
      const rows = await listBaasRestRows(restTable);
      setRestRows(rows);
    } catch {
      notifyRef.current.showError('Не удалось загрузить строки');
    } finally {
      setLoading(false);
    }
  };

  const onInsertRest = async () => {
    if (!restTable) return;
    setLoading(true);
    try {
      const obj = JSON.parse(restJson) as Record<string, unknown>;
      await insertBaasRow(restTable, obj);
      notifyRef.current.showSuccess('Строка добавлена');
      await onLoadRest();
    } catch {
      notifyRef.current.showError('Проверьте формат данных');
    } finally {
      setLoading(false);
    }
  };

  const onDeleteRow = async (id: string) => {
    if (!restTable) return;
    setLoading(true);
    try {
      await deleteBaasRow(restTable, id);
      notifyRef.current.showSuccess('Удалено');
      await onLoadRest();
    } catch {
      notifyRef.current.showError('Удаление не удалось');
    } finally {
      setLoading(false);
    }
  };

  const onCreateBucket = async () => {
    setLoading(true);
    try {
      await createBucket(newBucket.trim());
      notifyRef.current.showSuccess('Папка создана');
      await refreshBuckets();
    } catch {
      notifyRef.current.showError('Не удалось создать папку');
    } finally {
      setLoading(false);
    }
  };

  const onUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f || !uploadBucket) return;
    setLoading(true);
    try {
      await uploadBaasObject(uploadBucket, objectKey.trim() || f.name, f);
      notifyRef.current.showSuccess('Файл загружен');
    } catch {
      notifyRef.current.showError('Загрузка не удалась');
    } finally {
      setLoading(false);
      e.target.value = '';
    }
  };

  const onDownload = async () => {
    if (!uploadBucket || !objectKey.trim()) return;
    setLoading(true);
    try {
      const blob = await downloadBaasObject(uploadBucket, objectKey.trim());
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = objectKey.split('/').pop() || 'download';
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      notifyRef.current.showError('Скачивание не удалось');
    } finally {
      setLoading(false);
    }
  };

  const onChat = async () => {
    setLoading(true);
    setChatOut('');
    try {
      const r = await deepseekChat([{ role: 'user', content: chatIn }]);
      setChatOut(JSON.stringify(r, null, 2));
    } catch {
      notifyRef.current.showError('Помощник временно недоступен');
    } finally {
      setLoading(false);
    }
  };

  const value: BaasConsoleContextValue = {
    loading,
    rateLimited,
    rateLimitSecondsLeft,
    environments,
    activeEnvironmentId,
    activeEnvironment,
    setActiveEnvironmentId,
    createEnvironment,
    deleteEnvironment,
    reloadEnvironments,
    schemaName,
    sql,
    setSql,
    sqlResult,
    tables,
    newTable,
    setNewTable,
    restTable,
    setRestTable,
    restRows,
    restJson,
    setRestJson,
    buckets,
    newBucket,
    setNewBucket,
    uploadBucket,
    setUploadBucket,
    objectKey,
    setObjectKey,
    chatIn,
    setChatIn,
    chatOut,
    loadBaasBootstrap,
    refreshTables,
    refreshBuckets,
    onRunSql,
    onCreateTable,
    onLoadRest,
    onInsertRest,
    onDeleteRow,
    onCreateBucket,
    onUpload,
    onDownload,
    onChat,
  };

  return <BaasConsoleContext.Provider value={value}>{children}</BaasConsoleContext.Provider>;
};

export function useBaasConsole(): BaasConsoleContextValue {
  const ctx = useContext(BaasConsoleContext);
  if (!ctx) throw new Error('useBaasConsole must be used within BaasConsoleProvider');
  return ctx;
}
