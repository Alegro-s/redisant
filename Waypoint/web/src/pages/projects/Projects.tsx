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
  TextField,
  MenuItem,
  Alert,
  useTheme,
  Card,
  CardContent,
  Grid,
} from '@mui/material';
import {
  Delete as DeleteIcon,
  Refresh as RefreshIcon,
  Add as AddIcon,
  Visibility as VisibilityIcon,
  Folder as FolderIcon,
} from '@mui/icons-material';
import { DataGrid, GridColDef, GridRenderCellParams } from '@mui/x-data-grid';
import { useNotification } from '../../app/hooks/useNotification';
import api from '../../services/api';
import { useAuth } from '../../app/contexts/AuthContext';
import { useNavigate } from 'react-router-dom';

interface Project {
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

export const Projects: React.FC = () => {
  const navigate = useNavigate();
  const { isAdmin } = useAuth();
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editingProject, setEditingProject] = useState<Project | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    visibility: 'private' as 'private' | 'public',
  });
  const theme = useTheme();
  const { showSuccess, showError } = useNotification();

  useEffect(() => {
    void (async () => {
      try {
        const { data } = await api.get<{ onboarding_completed?: boolean }>('/me/workspace');
        if (data && data.onboarding_completed === false) {
          navigate('/dashboard/onboarding', { replace: true });
        }
      } catch {
        
      }
    })();
  }, [navigate]);

  const fetchProjects = async () => {
    setLoading(true);
    try {
      const response = await api.get(isAdmin ? '/admin/projects' : '/projects');
      const mapped = (response.data as any[]).map((p) => ({
        id: String(p.id),
        ownerId: String(p.ownerId ?? p.owner_id ?? ''),
        ownerName: p.ownerName ?? p.owner_name ?? undefined,
        name: String(p.name ?? ''),
        description: p.description ?? undefined,
        visibility: (p.visibility ?? 'private') as 'private' | 'public',
        rootFolder: p.rootFolder ?? p.root_folder ?? undefined,
        assetCount: p.assetCount ?? p.asset_count ?? undefined,
        createdAt: String(p.createdAt ?? p.created_at ?? new Date().toISOString()),
        updatedAt: String(p.updatedAt ?? p.updated_at ?? new Date().toISOString()),
      }));
      setProjects(mapped);
      setError('');
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to load projects');
      showError('Failed to load projects');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchProjects();
  }, []);

  const handleCreate = () => {
    setEditingProject(null);
    setFormData({ name: '', description: '', visibility: 'private' });
    setDialogOpen(true);
  };

  const handleEdit = (project: Project) => {
    setEditingProject(project);
    setFormData({
      name: project.name,
      description: project.description || '',
      visibility: project.visibility,
    });
    setDialogOpen(true);
  };

  const handleSave = async () => {
    try {
      if (editingProject) {
        if (isAdmin) {
          await api.put(`/admin/projects/${editingProject.id}`, formData);
          showSuccess('Project updated successfully');
        } else {
          showError('Редактирование проекта доступно только администратору.');
          return;
        }
      } else {
        await api.post('/projects', formData);
        showSuccess('Project created successfully');
      }
      fetchProjects();
      setDialogOpen(false);
    } catch (err: any) {
      showError(err.response?.data?.error || 'Failed to save project');
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Delete this project? All assets will be deleted as well.')) return;
    if (!isAdmin) {
      showError('Удаление проекта доступно только администратору.');
      return;
    }
    try {
      await api.delete(`/admin/projects/${id}`);
      showSuccess('Project deleted successfully');
      fetchProjects();
    } catch (err: any) {
      showError(err.response?.data?.error || 'Failed to delete project');
    }
  };

  const columns: GridColDef<Project>[] = [
    { field: 'id', headerName: 'ID', width: 200 },
    { field: 'name', headerName: 'Name', width: 200, renderCell: (params) => (
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
        <FolderIcon sx={{ color: theme.palette.warning.main }} />
        <Typography>{params.value}</Typography>
      </Box>
    )},
    { field: 'ownerName', headerName: 'Owner', width: 150, hideable: true },
    { field: 'description', headerName: 'Description', width: 250 },
    {
      field: 'visibility',
      headerName: 'Visibility',
      width: 120,
      renderCell: (params) => (
        <Chip
          label={params.value === 'public' ? 'Public' : 'Private'}
          color={params.value === 'public' ? 'success' : 'default'}
          size="small"
        />
      ),
    },
    {
      field: 'assetCount',
      headerName: 'Assets',
      width: 100,
      type: 'number',
    },
    {
      field: 'createdAt',
      headerName: 'Created',
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
          <Tooltip title="Edit">
            <IconButton onClick={() => handleEdit(params.row)} size="small">
              <VisibilityIcon fontSize="small" />
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
            Projects
          </Typography>
          <Typography variant="body2" color="text.secondary">
            {isAdmin ? 'Manage all projects in the system' : 'Ваши проекты и совместные проекты'}
          </Typography>
        </Box>
        <Box sx={{ display: 'flex', gap: 1 }}>
          <Tooltip title="Refresh">
            <IconButton onClick={fetchProjects} sx={{ bgcolor: theme.palette.background.paper }}>
              <RefreshIcon />
            </IconButton>
          </Tooltip>
          <Button variant="contained" startIcon={<AddIcon />} onClick={handleCreate}>
            Create Project
          </Button>
        </Box>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError('')}>
          {error}
        </Alert>
      )}

      <Box sx={{ height: 600, width: '100%' }}>
        <DataGrid
          rows={projects}
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
      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>{editingProject ? 'Edit Project' : 'Create Project'}</DialogTitle>
        <DialogContent>
          <TextField
            margin="dense"
            label="Project Name"
            fullWidth
            required
            value={formData.name}
            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
            sx={{ mb: 2 }}
          />
          <TextField
            margin="dense"
            label="Description"
            fullWidth
            multiline
            rows={3}
            value={formData.description}
            onChange={(e) => setFormData({ ...formData, description: e.target.value })}
            sx={{ mb: 2 }}
          />
          <TextField
            margin="dense"
            label="Visibility"
            select
            fullWidth
            value={formData.visibility}
            onChange={(e) => setFormData({ ...formData, visibility: e.target.value as 'private' | 'public' })}
          >
            <MenuItem value="private">Private</MenuItem>
            <MenuItem value="public">Public</MenuItem>
          </TextField>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
          <Button onClick={handleSave} variant="contained">Save</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};