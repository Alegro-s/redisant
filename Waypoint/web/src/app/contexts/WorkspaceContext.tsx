import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import api from '../../services/api';
import { useAuth } from './AuthContext';

export type PlanCode = 'basic' | 'pro';

export type WorkspaceSetupMode = 'rent' | 'connect';

export interface WorkspaceState {
  setupCompleted: boolean;
  setupMode: WorkspaceSetupMode | null;
  plan: PlanCode;
  serverConnected: boolean;
  connectionUrl?: string | null;
  agentApiKey?: string | null;
  ingestApiKey?: string | null;
  capabilities?: WorkspaceCapabilities;
}

export interface WorkspaceCapabilities {
  gitGb: number;
  storageGb: number;
  vcpu: number;
  realtime: boolean;
  maxServerRent: number;
}

interface WorkspaceContextType {
  workspace: WorkspaceState;
  capabilities: WorkspaceCapabilities;
  isLoading: boolean;
  refreshWorkspace: () => Promise<void>;
  
  saveWorkspace: (patch: Partial<WorkspaceState>) => Promise<boolean>;
}

const initialWorkspace: WorkspaceState = {
  setupCompleted: false,
  setupMode: null,
  plan: 'basic',
  serverConnected: false,
  connectionUrl: null,
  agentApiKey: null,
  ingestApiKey: null,
};

const basicCaps: WorkspaceCapabilities = {
  gitGb: 10,
  storageGb: 10,
  vcpu: 1,
  realtime: false,
  maxServerRent: 1,
};

const proCaps: WorkspaceCapabilities = {
  gitGb: 50,
  storageGb: 100,
  vcpu: 4,
  realtime: true,
  maxServerRent: 3,
};

const WorkspaceContext = createContext<WorkspaceContextType | undefined>(undefined);

const localStorageKey = 'workspaceStateV2';

const computeCaps = (plan: PlanCode, isAdmin: boolean): WorkspaceCapabilities => {
  if (!isAdmin) return plan === 'pro' ? proCaps : basicCaps;
  const base = plan === 'pro' ? proCaps : basicCaps;
  return {
    gitGb: base.gitGb * 2,
    storageGb: base.storageGb * 2,
    vcpu: Math.max(base.vcpu, 4),
    realtime: true,
    maxServerRent: base.maxServerRent + 2,
  };
};

export const WorkspaceProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { isAuthenticated, isAdmin } = useAuth();
  const [workspace, setWorkspace] = useState<WorkspaceState>(initialWorkspace);
  const [isLoading, setIsLoading] = useState(true);

  const readLocal = (): WorkspaceState => {
    try {
      const raw = localStorage.getItem(localStorageKey);
      if (!raw) return initialWorkspace;
      const parsed = JSON.parse(raw) as Partial<WorkspaceState>;
      return {
        setupCompleted: !!parsed.setupCompleted,
        setupMode: parsed.setupMode === 'rent' || parsed.setupMode === 'connect' ? parsed.setupMode : null,
        plan: parsed.plan === 'pro' ? 'pro' : 'basic',
        serverConnected: !!parsed.serverConnected,
        connectionUrl: parsed.connectionUrl ?? null,
        agentApiKey: parsed.agentApiKey ?? null,
        ingestApiKey: parsed.ingestApiKey ?? null,
      };
    } catch {
      return initialWorkspace;
    }
  };

  const writeLocal = (state: WorkspaceState) => {
    localStorage.setItem(localStorageKey, JSON.stringify(state));
  };

  const refreshWorkspace = useCallback(async () => {
    if (!isAuthenticated) {
      setWorkspace(initialWorkspace);
      setIsLoading(false);
      return;
    }
    setIsLoading(true);
    try {
      const { data } = await api.get('/me/workspace');
      const mapped: WorkspaceState = {
        setupCompleted: data?.onboarding_completed === true,
        setupMode: data?.db_mode === 'existing' ? 'connect' : data?.db_mode === 'cloud' ? 'rent' : null,
        plan: data?.plan === 'pro' ? 'pro' : 'basic',
        serverConnected: data?.db_mode === 'existing' ? true : Boolean(data?.connection_url),
        connectionUrl: data?.connection_url ?? null,
        agentApiKey: data?.agent_api_key ?? null,
        ingestApiKey: data?.ingest_api_key ?? null,
        capabilities:
          data?.capabilities && typeof data.capabilities === 'object'
            ? {
                gitGb: Number(data.capabilities.git_gb ?? basicCaps.gitGb),
                storageGb: Number(data.capabilities.storage_gb ?? basicCaps.storageGb),
                vcpu: Number(data.capabilities.vcpu ?? basicCaps.vcpu),
                realtime: Boolean(data.capabilities.realtime),
                maxServerRent: Number(data.capabilities.max_server_rent ?? basicCaps.maxServerRent),
              }
            : undefined,
      };
      setWorkspace(mapped);
      writeLocal(mapped);
    } catch {
      const fallback = readLocal();
      setWorkspace(fallback);
    } finally {
      setIsLoading(false);
    }
  }, [isAuthenticated]);

  const saveWorkspace = useCallback(
    async (patch: Partial<WorkspaceState>): Promise<boolean> => {
      const normalizedPatch = { ...patch };
      if (!isAdmin && normalizedPatch.plan === 'pro') {
        normalizedPatch.plan = 'basic';
      }
      const next: WorkspaceState = { ...workspace, ...normalizedPatch };
      setWorkspace(next);
      writeLocal(next);
      try {
        await api.put('/me/workspace', {
          onboarding_completed: next.setupCompleted,
          db_mode: next.setupMode === 'connect' ? 'existing' : next.setupMode === 'rent' ? 'cloud' : null,
          plan: next.plan,
          connection_url: next.serverConnected ? next.connectionUrl ?? null : null,
          server_hosting: next.plan === 'pro',
        });
        await refreshWorkspace();
        return true;
      } catch {
        return false;
      }
    },
    [workspace, isAdmin, refreshWorkspace],
  );

  useEffect(() => {
    void refreshWorkspace();
  }, [isAuthenticated, isAdmin, refreshWorkspace]);

  const value = useMemo(
    () => ({
      workspace,
      capabilities: workspace.capabilities ?? computeCaps(workspace.plan, isAdmin),
      isLoading,
      refreshWorkspace,
      saveWorkspace,
    }),
    [workspace, isAdmin, isLoading, refreshWorkspace, saveWorkspace],
  );

  return <WorkspaceContext.Provider value={value}>{children}</WorkspaceContext.Provider>;
};

export const useWorkspace = (): WorkspaceContextType => {
  const ctx = useContext(WorkspaceContext);
  if (!ctx) {
    throw new Error('useWorkspace must be used within WorkspaceProvider');
  }
  return ctx;
};
