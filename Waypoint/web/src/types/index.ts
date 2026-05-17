export interface User {
  id: string;
  email: string;
  phone?: string;
  fullName: string;
  nickname: string;
  avatarUrl?: string;
  role: 'user' | 'admin';
  blocked: boolean;
  coins: number;
  createdAt: string;
  updatedAt: string;
}

export interface Project {
  id: string;
  ownerId: string;
  ownerName?: string;
  name: string;
  description?: string;
  visibility: 'private' | 'public';
  rootFolder?: string;
  assetCount?: number;
  createdAt: string;
  updatedAt: string;
}

export interface Asset {
  id: string;
  projectId: string;
  projectName?: string;
  name: string;
  type: 'sprite' | 'script' | 'sound' | 'image';
  size: number;
  hash: string;
  storagePath: string;
  createdAt: string;
  updatedAt: string;
}

export interface MetricPoint {
  time: string;
  cpu: number;
  memory: number;
  total_memory: number;
  disk_io: number;
  network_rx: number;
  network_tx: number;
  requests: number;
}

export interface LogEntry {
  id: string;
  level: 'INFO' | 'WARN' | 'ERROR' | 'DEBUG';
  message: string;
  module?: string;
  file?: string;
  line?: number;
  createdAt: string;
}