import api from './api';

export interface NexusCloudProject {
  id: string;
  name: string;
  description: string | null;
  created_at: string;
  updated_at: string;
}

export async function listCloudProjects(): Promise<NexusCloudProject[]> {
  const { data } = await api.get<{ projects: NexusCloudProject[] }>('/me/lynx-cloud/projects');
  return data.projects;
}

export async function getCloudProject(id: string): Promise<NexusCloudProject> {
  const { data } = await api.get<NexusCloudProject>(`/me/lynx-cloud/projects/${id}`);
  return data;
}

export async function createCloudProject(name: string, description?: string): Promise<NexusCloudProject> {
  const { data } = await api.post<NexusCloudProject>('/me/lynx-cloud/projects', { name, description });
  return data;
}

export async function patchCloudProject(
  id: string,
  patch: { name?: string; description?: string | null }
): Promise<NexusCloudProject> {
  const { data } = await api.patch<NexusCloudProject>(`/me/lynx-cloud/projects/${id}`, patch);
  return data;
}

export async function deleteCloudProject(id: string): Promise<void> {
  await api.delete(`/me/lynx-cloud/projects/${id}`);
}

export interface NexusCloudBuildJob {
  id: string;
  project_id: string;
  owner_id: string;
  status: string;
  ref_name: string | null;
  label: string | null;
  log_excerpt: string | null;
  meta: Record<string, unknown>;
  bullmq_job_id: string | null;
  created_at: string;
  started_at: string | null;
  finished_at: string | null;
  error_message: string | null;
}

export async function listMyCloudBuilds(): Promise<NexusCloudBuildJob[]> {
  const { data } = await api.get<{ builds: NexusCloudBuildJob[] }>('/me/lynx-cloud/builds');
  return data.builds;
}

export async function listProjectBuilds(projectId: string): Promise<NexusCloudBuildJob[]> {
  const { data } = await api.get<{ builds: NexusCloudBuildJob[] }>(
    `/me/lynx-cloud/projects/${projectId}/builds`
  );
  return data.builds;
}

export async function createCloudBuild(
  projectId: string,
  body: { ref_name?: string; label?: string }
): Promise<NexusCloudBuildJob> {
  const { data } = await api.post<NexusCloudBuildJob>(`/me/lynx-cloud/projects/${projectId}/builds`, body);
  return data;
}
