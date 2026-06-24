import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import {
  clearLynxAuth,
  fetchLynxProfile,
  getLynxAuthToken,
  isLynxOps,
  type LynxProfile,
} from '../lib/lynxAuth';

type HubAuthContextValue = {
  user: LynxProfile | null;
  loading: boolean;
  isAuthenticated: boolean;
  isOps: boolean;
  refresh: () => Promise<LynxProfile | null>;
  signOut: () => void;
};

const HubAuthContext = createContext<HubAuthContextValue | null>(null);

export function HubAuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<LynxProfile | null>(null);
  const [loading, setLoading] = useState(true);

  const refresh = useCallback(async (): Promise<LynxProfile | null> => {
    const token = getLynxAuthToken();
    if (!token) {
      setUser(null);
      setLoading(false);
      return null;
    }
    setLoading(true);
    const profile = await fetchLynxProfile();
    setUser(profile);
    setLoading(false);
    return profile;
  }, []);

  const signOut = useCallback(() => {
    clearLynxAuth();
    setUser(null);
  }, []);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  useEffect(() => {
    const onStorage = (e: StorageEvent) => {
      if (e.key === 'lynx_auth_token') void refresh();
    };
    window.addEventListener('storage', onStorage);
    return () => window.removeEventListener('storage', onStorage);
  }, [refresh]);

  const value = useMemo<HubAuthContextValue>(
    () => ({
      user,
      loading,
      isAuthenticated: Boolean(getLynxAuthToken()),
      isOps: isLynxOps(user),
      refresh,
      signOut,
    }),
    [user, loading, refresh, signOut],
  );

  return <HubAuthContext.Provider value={value}>{children}</HubAuthContext.Provider>;
}

export function useHubAuth(): HubAuthContextValue {
  const ctx = useContext(HubAuthContext);
  if (!ctx) throw new Error('useHubAuth requires HubAuthProvider');
  return ctx;
}
