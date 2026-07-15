import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api/client';
import type { User, Checkpoint } from '../types';

interface UserWithStats extends User {
  pendingCount: number;
  completedCount: number;
}

export default function UsersPage() {
  const [users, setUsers] = useState<UserWithStats[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  useEffect(() => { loadData(); }, []);

  const loadData = async () => {
    try {
      const [userRes, cpRes] = await Promise.all([
        api.get<{ users: User[] }>('/users'),
        api.get<{ checkpoints: Checkpoint[] }>('/checkpoints'),
      ]);

      const withStats: UserWithStats[] = userRes.users.map(u => {
        const cps = cpRes.checkpoints.filter(c => c.user_id === u.id);
        return { ...u, pendingCount: cps.filter(c => c.status === 'pending').length, completedCount: cps.filter(c => c.status === 'completed').length };
      });
      setUsers(withStats);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: number, name: string) => {
    if (!confirm(`Delete user "${name}"? This will also remove their checkpoints.`)) return;
    try {
      await api.delete(`/users/${id}`);
      setUsers(prev => prev.filter(u => u.id !== id));
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Delete failed');
    }
  };

  if (loading) return <div style={{ padding: '2rem', textAlign: 'center' }}>Loading users...</div>;

  return (
    <div>
      <div className="card">
        <div className="flex items-center mb-4">
          <h2>Users</h2>
          <button className="btn btn-primary btn-sm ml-auto" onClick={() => navigate('/users/new')}>+ New User</button>
        </div>
        {error && <div className="error-msg mb-4">{error}</div>}
        <table>
          <thead>
            <tr>
              <th>Username</th>
              <th>Display Name</th>
              <th>Role</th>
              <th>Checkpoints</th>
              <th>Created</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {users.map(u => (
              <tr key={u.id}>
                <td>{u.username}</td>
                <td><strong>{u.display_name}</strong></td>
                <td><span className="status-badge" style={{ background: u.role === 'admin' ? '#dbeafe' : '#f3f4f6', color: u.role === 'admin' ? '#1e40af' : '#374151' }}>{u.role}</span></td>
                <td>
                  {u.role === 'worker' ? (
                    <span>
                      <span className="status-badge status-pending" style={{ marginRight: 4 }}>{u.pendingCount} pending</span>
                      <span className="status-badge status-completed">{u.completedCount} done</span>
                    </span>
                  ) : <span className="text-muted text-sm">—</span>}
                </td>
                <td className="text-sm text-muted">{new Date(u.created_at).toLocaleDateString()}</td>
                <td>
                  <div className="flex gap-2">
                    {u.role === 'worker' && (
                      <button className="btn btn-primary btn-sm" onClick={() => navigate(`/users/${u.id}/checkpoints`)}>
                        {u.pendingCount > 0 || u.completedCount > 0 ? 'View & Assign' : 'Assign'}
                      </button>
                    )}
                    <button className="btn btn-secondary btn-sm" onClick={() => navigate(`/users/${u.id}/edit`)}>Edit</button>
                    {u.role !== 'admin' && (
                      <button className="btn btn-danger btn-sm" onClick={() => handleDelete(u.id, u.display_name)}>Delete</button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
