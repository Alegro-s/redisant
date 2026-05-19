import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import api from '../../services/api';
import authApi from '../../services/authApi';
import { Permission, permissionsForRole, UserRole } from '../authz';

interface User {
  id: string;
  email: string;
  fullName: string;
  nickname: string;
  role: UserRole;
  avatarUrl?: string;
  realms: string[];
}

interface AuthContextType {
  user: User | null;
  
  token: string | null;
  isLoading: boolean;
  login: (login: string, password: string) => Promise<void>;
  /** Сохранить JWT после регистрации / подтверждения почты */
  establishSession: (token: string) => Promise<void>;
  logout: () => void;
  refreshProfile: () => Promise<void>;
  linkRealm: (realm: 'nexus' | 'metric', password: string) => Promise<void>;
  activateAdminKey: (key: string) => Promise<void>;
  activateNexusKey: (key: string) => Promise<void>;
  isAuthenticated: boolean;
  isAdmin: boolean;
  isNexus: boolean;
  permissions: Permission[];
  can: (permission: Permission) => boolean;
}

const AUTH_TOKEN_KEY = 'metric_auth_token';

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
};

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const permissions = user ? permissionsForRole(user.role) : [];

  const mapProfile = (d: Record<string, unknown>): User => {
    const realmsRaw = d.realms;
    const realms = Array.isArray(realmsRaw)
      ? realmsRaw.map((x) => String(x).toLowerCase())
      : ['nexus', 'metric'];
    return {
      id: String(d.id),
      email: String(d.email),
      fullName: String(d.full_name ?? ''),
      nickname: String(d.nickname),
      role:
        d.role === 'nexus' ? 'nexus' : d.role === 'admin' ? 'admin' : 'user',
      avatarUrl: d.avatar_url ? String(d.avatar_url) : undefined,
      realms,
    };
  };

  const applyBearer = (t: string | null) => {
    if (t) {
      const h = `Bearer ${t}`;
      api.defaults.headers.common.Authorization = h;
      authApi.defaults.headers.common.Authorization = h;
    } else {
      delete api.defaults.headers.common.Authorization;
      delete authApi.defaults.headers.common.Authorization;
    }
  };

  const loadProfile = async () => {
    try {
      const response = await authApi.get<Record<string, unknown>>('/profile');
      setUser(mapProfile(response.data));
    } catch {
      setToken(null);
      setUser(null);
      sessionStorage.removeItem(AUTH_TOKEN_KEY);
      applyBearer(null);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    const stored = sessionStorage.getItem(AUTH_TOKEN_KEY);
    if (stored && stored.length > 0) {
      setToken(stored);
      applyBearer(stored);
      void loadProfile();
      return;
    }
    setIsLoading(false);
  }, []);

  const establishSession = async (tokenStr: string) => {
    setToken(tokenStr);
    applyBearer(tokenStr);
    sessionStorage.setItem(AUTH_TOKEN_KEY, tokenStr);
    const userResponse = await authApi.get<Record<string, unknown>>('/profile');
    setUser(mapProfile(userResponse.data));
  };

  const login = async (loginStr: string, password: string) => {
    const response = await authApi.post<{ token: string }>('/login', { login: loginStr, password });
    await establishSession(response.data.token);
  };

  const refreshProfile = async () => {
    try {
      const userResponse = await authApi.get<Record<string, unknown>>('/profile');
      setUser(mapProfile(userResponse.data));
    } catch {
      setUser(null);
    }
  };

  const linkRealm = async (realm: 'nexus' | 'metric', password: string) => {
    await authApi.post('/auth/realms/link', { realm, password });
    await refreshProfile();
  };

  const activateAdminKey = async (key: string) => {
    await authApi.post('/auth/admin/activate', { key: key.trim() });
    await refreshProfile();
  };

  const activateNexusKey = async (key: string) => {
    await authApi.post('/auth/nexus/activate', { key: key.trim() });
    await refreshProfile();
  };

  const logout = () => {
    void authApi
      .post('/logout')
      .catch(() => {})
      .finally(() => {
        setToken(null);
        applyBearer(null);
        setUser(null);
        sessionStorage.removeItem(AUTH_TOKEN_KEY);
      });
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        isLoading,
        login,
        establishSession,
        logout,
        refreshProfile,
        linkRealm,
        activateAdminKey,
        activateNexusKey,
        isAuthenticated: !!user,
        isAdmin: user?.role === 'admin' || user?.role === 'nexus',
        isNexus: user?.role === 'nexus',
        permissions,
        can: (permission: Permission) => permissions.includes(permission),
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};
