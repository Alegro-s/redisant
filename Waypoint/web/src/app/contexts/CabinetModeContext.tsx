import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';

export type CabinetMode = 'business' | 'developer';

const STORAGE_KEY = 'waypointCabinetModeV1';

interface CabinetModeContextType {
  mode: CabinetMode;
  setMode: (m: CabinetMode) => void;
  toggleMode: () => void;
}

const CabinetModeContext = createContext<CabinetModeContextType | undefined>(undefined);

function readStored(): CabinetMode {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw === 'developer' || raw === 'business') return raw;
  } catch {
    
  }
  return 'business';
}

export const CabinetModeProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [mode, setModeState] = useState<CabinetMode>(() => readStored());

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, mode);
    } catch {
      
    }
  }, [mode]);

  const setMode = useCallback((m: CabinetMode) => setModeState(m), []);
  const toggleMode = useCallback(() => {
    setModeState((prev) => (prev === 'business' ? 'developer' : 'business'));
  }, []);

  const value = useMemo(() => ({ mode, setMode, toggleMode }), [mode, setMode, toggleMode]);

  return <CabinetModeContext.Provider value={value}>{children}</CabinetModeContext.Provider>;
};

export function useCabinetMode(): CabinetModeContextType {
  const ctx = useContext(CabinetModeContext);
  if (!ctx) throw new Error('useCabinetMode must be used within CabinetModeProvider');
  return ctx;
}
