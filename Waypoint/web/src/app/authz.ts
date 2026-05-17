export type UserRole = 'user' | 'admin' | 'nexus';

export type Permission =
  | 'dashboard:view'
  | 'projects:view'
  | 'assets:view'
  | 'workspace:manage'
  | 'metrics:view'
  | 'database:query'
  | 'module-testing:run'
  | 'users:manage'
  | 'instances:manage'
  | 'realtime:manage'
  | 'versions:manage'
  | 'logs:view'
  | 'jobs:manage'
  | 'ai:analyze'
  | 'admin-keys:manage'
  | 'registration-log:view';

const BASE_PERMISSIONS: Permission[] = [
  'dashboard:view',
  'projects:view',
  'assets:view',
  'workspace:manage',
  'metrics:view',
  'database:query',
  'module-testing:run',
];

const ADMIN_EXTRA: Permission[] = [
  'users:manage',
  'instances:manage',
  'realtime:manage',
  'logs:view',
  'jobs:manage',
  'ai:analyze',
  'registration-log:view',
];


const NEXUS_EXTRA: Permission[] = ['admin-keys:manage', 'versions:manage'];

export function permissionsForRole(role: UserRole): Permission[] {
  if (role === 'nexus') {
    return [...BASE_PERMISSIONS, ...ADMIN_EXTRA, ...NEXUS_EXTRA];
  }
  if (role === 'admin') {
    return [...BASE_PERMISSIONS, ...ADMIN_EXTRA];
  }
  return BASE_PERMISSIONS;
}
