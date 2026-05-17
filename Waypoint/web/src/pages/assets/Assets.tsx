import React, { useEffect, useState } from 'react';
import {
  Box,
  Typography,
  IconButton,
  Tooltip,
  Chip,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Alert,
  useTheme,
  LinearProgress,
  Card,
  CardContent,
  Grid,
  Avatar,
  alpha,
} from '@mui/material';
import {
  Delete as DeleteIcon,
  Download as DownloadIcon,
  Refresh as RefreshIcon,
  CloudUpload as UploadIcon,
  Image as ImageIcon,
  Code as CodeIcon,
  MusicNote as MusicIcon,
} from '@mui/icons-material';
import { DataGrid, GridColDef, GridRenderCellParams } from '@mui/x-data-grid';
import { useNotification } from '../../app/hooks/useNotification';
import api from '../../services/api';
import { useAuth } from '../../app/contexts/AuthContext';

interface Asset {
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

export const Assets: React.FC = () => {
  const { isAdmin } = useAuth();
  const [assets, setAssets] = useState<Asset[]>([]);
  const [projectIdForUpload, setProjectIdForUpload] = useState('');
  const [projects, setProjects] = useState<Array<{ id: string; name: string }>>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [uploadDialogOpen, setUploadDialogOpen] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [uploading, setUploading] = useState(false);
  const theme = useTheme();
  const { showSuccess, showError } = useNotification();

  const fetchAssets = async () => {
    setLoading(true);
    try {
      if (isAdmin) {
        const response = await api.get('/admin/assets');
        const mapped = (response.data as any[]).map((a) => ({
          id: String(a.id),
          projectId: String(a.projectId ?? a.project_id ?? ''),
          projectName: a.projectName ?? a.project_name ?? undefined,
          name: String(a.name ?? ''),
          type: (a.type ?? 'image') as Asset['type'],
          size: Number(a.size ?? 0),
          hash: String(a.hash ?? ''),
          storagePath: String(a.storagePath ?? a.storage_path ?? ''),
          createdAt: String(a.createdAt ?? a.created_at ?? new Date().toISOString()),
          updatedAt: String(a.updatedAt ?? a.updated_at ?? new Date().toISOString()),
        }));
        setAssets(mapped);
      } else {
        const pr = await api.get('/projects');
        const p = (pr.data as any[]).map((x) => ({ id: String(x.id), name: String(x.name ?? 'Project') }));
        setProjects(p);
        const allAssets: Asset[] = [];
        for (const proj of p) {
          try {
            const r = await api.get(`/projects/${proj.id}/assets`);
            const mapped = (r.data as any[]).map((a) => ({
              id: String(a.id),
              projectId: String(a.projectId ?? a.project_id ?? proj.id),
              projectName: proj.name,
              name: String(a.name ?? ''),
              type: (a.type ?? 'image') as Asset['type'],
              size: Number(a.size ?? 0),
              hash: String(a.hash ?? ''),
              storagePath: String(a.storagePath ?? a.storage_path ?? ''),
              createdAt: String(a.createdAt ?? a.created_at ?? new Date().toISOString()),
              updatedAt: String(a.updatedAt ?? a.updated_at ?? new Date().toISOString()),
            }));
            allAssets.push(...mapped);
          } catch {
          }
        }
        setAssets(allAssets);
      }
      setError('');
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to load assets');
      showError('Failed to load assets');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAssets();
  }, []);

  const handleFileSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    if (event.target.files && event.target.files[0]) {
      setSelectedFile(event.target.files[0]);
    }
  };

  const handleUpload = async () => {
    if (!selectedFile) return;

    setUploading(true);
    setUploadProgress(0);

    const formData = new FormData();
    formData.append('file', selectedFile);
    formData.append('name', selectedFile.name);
    formData.append('type', getAssetType(selectedFile.name));

    try {
      const uploadUrl = isAdmin
        ? '/admin/assets/upload'
        : `/projects/${projectIdForUpload || projects[0]?.id || ''}/assets`;
      if (!isAdmin && !uploadUrl.includes('/projects/')) {
        showError('Сначала создайте проект');
        return;
      }
      const response = await api.post(uploadUrl, formData, {
        onUploadProgress: (progressEvent) => {
          if (progressEvent.total) {
            const percent = (progressEvent.loaded / progressEvent.total) * 100;
            setUploadProgress(percent);
          }
        },
      });
      showSuccess('Asset uploaded successfully');
      fetchAssets();
      setUploadDialogOpen(false);
      setSelectedFile(null);
      setProjectIdForUpload('');
      setUploadProgress(0);
    } catch (err: any) {
      showError(err.response?.data?.error || 'Failed to upload asset');
    } finally {
      setUploading(false);
    }
  };

  const getAssetType = (filename: string): string => {
    const ext = filename.split('.').pop()?.toLowerCase();
    if (['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp'].includes(ext || '')) return 'image';
    if (['js', 'ts', 'py', 'rs', 'go', 'java'].includes(ext || '')) return 'script';
    if (['mp3', 'wav', 'ogg', 'flac'].includes(ext || '')) return 'sound';
    return 'sprite';
  };

  const getAssetIcon = (type: string) => {
    switch (type) {
      case 'image': return <ImageIcon />;
      case 'script': return <CodeIcon />;
      case 'sound': return <MusicIcon />;
      default: return <ImageIcon />;
    }
  };

  const getAssetColor = (type: string) => {
    switch (type) {
      case 'image': return theme.palette.primary.main;
      case 'script': return theme.palette.info.main;
      case 'sound': return theme.palette.warning.main;
      default: return theme.palette.info.main;
    }
  };

  const formatBytes = (bytes: number) => {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Delete this asset?')) return;
    if (!isAdmin) {
      showError('Удаление ассетов доступно только администратору.');
      return;
    }
    try {
      await api.delete(`/admin/assets/${id}`);
      showSuccess('Asset deleted successfully');
      fetchAssets();
    } catch (err: any) {
      showError(err.response?.data?.error || 'Failed to delete asset');
    }
  };

  const handleDownload = async (storagePath: string, name: string) => {
    try {
      const response = await api.get(`/assets/${storagePath}`, {
        responseType: 'blob',
      });
      const url = window.URL.createObjectURL(new Blob([response.data]));
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', name);
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
    } catch (err) {
      showError('Failed to download asset');
    }
  };

  const columns: GridColDef<Asset>[] = [
    {
      field: 'preview',
      headerName: '',
      width: 60,
      sortable: false,
      renderCell: (params) => (
        <Avatar sx={{ bgcolor: alpha(getAssetColor(params.row.type), 0.1), color: getAssetColor(params.row.type) }}>
          {getAssetIcon(params.row.type)}
        </Avatar>
      ),
    },
    { field: 'id', headerName: 'ID', width: 200 },
    { field: 'name', headerName: 'Name', width: 200 },
    { field: 'projectName', headerName: 'Project', width: 150 },
    {
      field: 'type',
      headerName: 'Type',
      width: 100,
      renderCell: (params) => (
        <Chip
          label={params.value}
          size="small"
          sx={{
            bgcolor: alpha(getAssetColor(params.value), 0.1),
            color: getAssetColor(params.value),
          }}
        />
      ),
    },
    {
      field: 'size',
      headerName: 'Size',
      width: 100,
      valueFormatter: (params) => formatBytes(params.value as number),
    },
    {
      field: 'createdAt',
      headerName: 'Uploaded',
      width: 180,
      valueFormatter: (params) => new Date(params.value).toLocaleString(),
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 100,
      sortable: false,
      renderCell: (params) => (
        <Box>
          <Tooltip title="Download">
            <IconButton onClick={() => handleDownload(params.row.storagePath, params.row.name)} size="small">
              <DownloadIcon fontSize="small" />
            </IconButton>
          </Tooltip>
          <Tooltip title="Delete">
            <IconButton onClick={() => handleDelete(params.row.id)} size="small" color="error">
              <DeleteIcon fontSize="small" />
            </IconButton>
          </Tooltip>
        </Box>
      ),
    },
  ];

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
        <Box>
          <Typography variant="h4" sx={{ fontWeight: 700, mb: 1 }}>
            Assets
          </Typography>
          <Typography variant="body2" color="text.secondary">
            {isAdmin ? 'Manage all uploaded assets and files' : 'Ваши файлы во всех доступных проектах'}
          </Typography>
        </Box>
        <Box sx={{ display: 'flex', gap: 1 }}>
          <Tooltip title="Refresh">
            <IconButton onClick={fetchAssets} sx={{ bgcolor: theme.palette.background.paper }}>
              <RefreshIcon />
            </IconButton>
          </Tooltip>
          <Button variant="contained" startIcon={<UploadIcon />} onClick={() => setUploadDialogOpen(true)}>
            Upload Asset
          </Button>
        </Box>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}

      {}
      <Grid container spacing={3} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography variant="caption" color="text.secondary">Total Assets</Typography>
              <Typography variant="h4">{assets.length}</Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography variant="caption" color="text.secondary">Total Size</Typography>
              <Typography variant="h4">{formatBytes(assets.reduce((sum, a) => sum + a.size, 0))}</Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography variant="caption" color="text.secondary">Images</Typography>
              <Typography variant="h4">{assets.filter(a => a.type === 'image').length}</Typography>
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Typography variant="caption" color="text.secondary">Scripts</Typography>
              <Typography variant="h4">{assets.filter(a => a.type === 'script').length}</Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <Box sx={{ height: 500, width: '100%' }}>
        <DataGrid
          rows={assets}
          columns={columns}
          loading={loading}
          pageSizeOptions={[10, 25, 50]}
          initialState={{ pagination: { paginationModel: { pageSize: 10 } } }}
          disableRowSelectionOnClick
          sx={{
            borderRadius: 3,
            border: `1px solid ${theme.palette.divider}`,
          }}
        />
      </Box>

      {}
      <Dialog open={uploadDialogOpen} onClose={() => !uploading && setUploadDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Upload Asset</DialogTitle>
        <DialogContent>
          <Box sx={{ mt: 2 }}>
            <input
              type="file"
              onChange={handleFileSelect}
              style={{ display: 'none' }}
              id="asset-file-input"
            />
            <label htmlFor="asset-file-input">
              <Button
                variant="outlined"
                component="span"
                fullWidth
                sx={{ mb: 2, py: 2 }}
              >
                Select File
              </Button>
            </label>
            {selectedFile && (
              <Typography variant="body2" sx={{ mb: 2 }}>
                Selected: {selectedFile.name} ({formatBytes(selectedFile.size)})
              </Typography>
            )}
            {!isAdmin && (
              <Box sx={{ mb: 2 }}>
                <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mb: 1 }}>
                  Проект для загрузки
                </Typography>
                <select
                  value={projectIdForUpload}
                  onChange={(e) => setProjectIdForUpload(e.target.value)}
                  style={{ width: '100%', minHeight: 36 }}
                >
                  <option value="">Выберите проект</option>
                  {projects.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.name}
                    </option>
                  ))}
                </select>
              </Box>
            )}
            {uploading && (
              <Box sx={{ width: '100%', mt: 2 }}>
                <LinearProgress variant="determinate" value={uploadProgress} />
                <Typography variant="caption" sx={{ mt: 1, display: 'block', textAlign: 'center' }}>
                  {uploadProgress.toFixed(0)}%
                </Typography>
              </Box>
            )}
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setUploadDialogOpen(false)} disabled={uploading}>Cancel</Button>
          <Button onClick={handleUpload} variant="contained" disabled={!selectedFile || uploading || (!isAdmin && !projectIdForUpload && projects.length > 0)}>
            Upload
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};