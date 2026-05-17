import React, { useEffect, useState } from 'react';
import {
  Box,
  Typography,
  IconButton,
  Tooltip,
  Chip,
  Avatar,
  Button,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  TextField,
  MenuItem,
  Alert,
  useTheme,
} from '@mui/material';
import {
  Edit as EditIcon,
  Delete as DeleteIcon,
  Block as BlockIcon,
  CheckCircle as CheckCircleIcon,
  Refresh as RefreshIcon,
  Add as AddIcon,
} from '@mui/icons-material';
import { DataGrid, GridColDef, GridRenderCellParams } from '@mui/x-data-grid';
import { useNotification } from '../../app/hooks/useNotification';
import api from '../../services/api';

interface User {
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

export const Users: React.FC = () => {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selectedUser, setSelectedUser] = useState<User | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [dialogMode, setDialogMode] = useState<'edit' | 'block' | 'delete'>('edit');
  const [editCoins, setEditCoins] = useState(0);
  const [editRole, setEditRole] = useState<'user' | 'admin'>('user');
  const [blockReason, setBlockReason] = useState('');
  const theme = useTheme();
  const { showSuccess, showError } = useNotification();

  const fetchUsers = async () => {
    setLoading(true);
    try {
      const response = await api.get('/admin/users');
      setUsers(response.data);
      setError('');
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to load users');
      showError('Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const handleEdit = (user: User) => {
    setSelectedUser(user);
    setEditCoins(user.coins);
    setEditRole(user.role);
    setDialogMode('edit');
    setDialogOpen(true);
  };

  const handleBlock = (user: User) => {
    setSelectedUser(user);
    setBlockReason('');
    setDialogMode('block');
    setDialogOpen(true);
  };

  const handleDelete = (user: User) => {
    setSelectedUser(user);
    setDialogMode('delete');
    setDialogOpen(true);
  };

  const handleEditSave = async () => {
    if (!selectedUser) return;
    try {
      await api.put(`/admin/users/${selectedUser.id}`, {
        fullName: selectedUser.fullName,
        role: editRole,
        coins: editCoins,
      });
      showSuccess('User updated successfully');
      fetchUsers();
      setDialogOpen(false);
    } catch (err: any) {
      showError(err.response?.data?.error || 'Failed to update user');
    }
  };

  const handleBlockConfirm = async () => {
    if (!selectedUser) return;
    try {
      await api.post(`/admin/users/${selectedUser.id}/block`, {
        blocked: !selectedUser.blocked,
        reason: blockReason,
      });
      showSuccess(selectedUser.blocked ? 'User unblocked' : 'User blocked');
      fetchUsers();
      setDialogOpen(false);
    } catch (err: any) {
      showError(err.response?.data?.error || 'Failed to update user status');
    }
  };

  const handleDeleteConfirm = async () => {
    if (!selectedUser) return;
    try {
      await api.delete(`/admin/users/${selectedUser.id}`);
      showSuccess('User deleted successfully');
      fetchUsers();
      setDialogOpen(false);
    } catch (err: any) {
      showError(err.response?.data?.error || 'Failed to delete user');
    }
  };

  const columns: GridColDef<User>[] = [
    {
      field: 'avatar',
      headerName: '',
      width: 50,
      sortable: false,
      renderCell: (params) => (
        <Avatar
          src={params.row.avatarUrl}
          sx={{ width: 32, height: 32, bgcolor: theme.palette.primary.main }}
        >
          {params.row.fullName?.charAt(0) || params.row.nickname?.charAt(0)}
        </Avatar>
      ),
    },
    { field: 'id', headerName: 'ID', width: 200 },
    { field: 'email', headerName: 'Email', width: 200 },
    { field: 'fullName', headerName: 'Full Name', width: 180 },
    { field: 'nickname', headerName: 'Nickname', width: 150 },
    {
      field: 'role',
      headerName: 'Role',
      width: 100,
      renderCell: (params) => (
        <Chip
          label={params.value}
          color={params.value === 'admin' ? 'secondary' : 'default'}
          size="small"
        />
      ),
    },
    {
      field: 'blocked',
      headerName: 'Status',
      width: 100,
      renderCell: (params) => (
        <Chip
          label={params.value ? 'Blocked' : 'Active'}
          color={params.value ? 'error' : 'success'}
          size="small"
        />
      ),
    },
    {
      field: 'coins',
      headerName: 'Coins',
      width: 100,
      type: 'number',
      valueFormatter: (params) => params.value?.toLocaleString() ?? '0',
    },
    {
      field: 'createdAt',
      headerName: 'Registered',
      width: 180,
      valueFormatter: (params) => new Date(params.value).toLocaleString(),
    },
    {
      field: 'actions',
      headerName: 'Actions',
      width: 120,
      sortable: false,
      renderCell: (params) => (
        <Box>
          <Tooltip title="Edit">
            <IconButton onClick={() => handleEdit(params.row)} size="small">
              <EditIcon fontSize="small" />
            </IconButton>
          </Tooltip>
          <Tooltip title={params.row.blocked ? 'Unblock' : 'Block'}>
            <IconButton onClick={() => handleBlock(params.row)} size="small" color="warning">
              <BlockIcon fontSize="small" />
            </IconButton>
          </Tooltip>
          <Tooltip title="Delete">
            <IconButton onClick={() => handleDelete(params.row)} size="small" color="error">
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
            Users
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Manage system users and their permissions
          </Typography>
        </Box>
        <Box sx={{ display: 'flex', gap: 1 }}>
          <Tooltip title="Refresh">
            <IconButton onClick={fetchUsers} sx={{ bgcolor: theme.palette.background.paper }}>
              <RefreshIcon />
            </IconButton>
          </Tooltip>
          <Button variant="contained" startIcon={<AddIcon />}>
            Add User
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
          rows={users}
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
      <Dialog open={dialogOpen && dialogMode === 'edit'} onClose={() => setDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Edit User</DialogTitle>
        <DialogContent>
          <TextField
            margin="dense"
            label="Full Name"
            fullWidth
            value={selectedUser?.fullName || ''}
            onChange={(e) => setSelectedUser(prev => prev ? { ...prev, fullName: e.target.value } : null)}
          />
          <TextField
            margin="dense"
            label="Role"
            select
            fullWidth
            value={editRole}
            onChange={(e) => setEditRole(e.target.value as 'user' | 'admin')}
          >
            <MenuItem value="user">User</MenuItem>
            <MenuItem value="admin">Admin</MenuItem>
          </TextField>
          <TextField
            margin="dense"
            label="Coins"
            type="number"
            fullWidth
            value={editCoins}
            onChange={(e) => setEditCoins(parseInt(e.target.value))}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
          <Button onClick={handleEditSave} variant="contained">Save</Button>
        </DialogActions>
      </Dialog>

      {}
      <Dialog open={dialogOpen && dialogMode === 'block'} onClose={() => setDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          {selectedUser?.blocked ? 'Unblock' : 'Block'} User
        </DialogTitle>
        <DialogContent>
          <Typography variant="body2" sx={{ mb: 2 }}>
            Are you sure you want to {selectedUser?.blocked ? 'unblock' : 'block'} {selectedUser?.fullName || selectedUser?.nickname}?
          </Typography>
          <TextField
            margin="dense"
            label="Reason (optional)"
            fullWidth
            multiline
            rows={3}
            value={blockReason}
            onChange={(e) => setBlockReason(e.target.value)}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
          <Button
            onClick={handleBlockConfirm}
            variant="contained"
            color={selectedUser?.blocked ? 'success' : 'error'}
          >
            {selectedUser?.blocked ? 'Unblock' : 'Block'}
          </Button>
        </DialogActions>
      </Dialog>

      {}
      <Dialog open={dialogOpen && dialogMode === 'delete'} onClose={() => setDialogOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Delete User</DialogTitle>
        <DialogContent>
          <Typography variant="body2" sx={{ mb: 2 }}>
            Are you sure you want to delete {selectedUser?.fullName || selectedUser?.nickname}? This action cannot be undone.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialogOpen(false)}>Cancel</Button>
          <Button onClick={handleDeleteConfirm} variant="contained" color="error">
            Delete
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};