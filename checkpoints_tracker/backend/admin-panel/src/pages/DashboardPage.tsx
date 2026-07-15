import { useEffect, useState } from 'react';
import { api } from '../api/client';
import type { User, Checkpoint } from '../types';
import { Link } from 'react-router-dom';

interface UserWithCheckpoints extends User {
  checkpoints: Checkpoint[];
  pendingCount: number;
  completedCount: number;
  lastUpdated: string | null;
}

export default function DashboardPage() {
  const [users, setUsers] = useState<UserWithCheckpoints[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    try {
      const [userRes, cpRes] = await Promise.all([
        api.get<{ users: User[] }>('/users'),
        api.get<{ checkpoints: Checkpoint[] }>('/checkpoints'),
      ]);

      const usersWithCp: UserWithCheckpoints[] = userRes.users.map(u => {
        const userCps = cpRes.checkpoints.filter(c => c.user_id === u.id);
        return {
          ...u,
          checkpoints: userCps,
          pendingCount: userCps.filter(c => c.status === 'pending').length,
          completedCount: userCps.filter(c => c.status === 'completed').length,
          lastUpdated: userCps.reduce(
            (latest, c) => (c.last_checked_at && (!latest || c.last_checked_at > latest) ? c.last_checked_at : latest),
            null as string | null
          ),
        };
      });

      setUsers(usersWithCp);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load data');
    } finally {
      setLoading(false);
    }
  };

  const totalWorkers = users.filter(u => u.role === 'worker').length;
  const totalCheckpoints = users.reduce((s, u) => s + u.checkpoints.length, 0);
  const totalCompleted = users.reduce((s, u) => s + u.completedCount, 0);
  const totalPending = totalCheckpoints - totalCompleted;

  if (loading) return <div style={{ padding: '2rem', textAlign: 'center' }}>Loading dashboard...</div>;
  if (error) return <div className="error-msg">{error}</div>;

  return (
    <div>
      <div className="stats-grid">
        <div className="stat-card">
          <h3>Workers</h3>
          <div className="value">{totalWorkers}</div>
        </div>
        <div className="stat-card">
          <h3>Total Checkpoints</h3>
          <div className="value">{totalCheckpoints}</div>
        </div>
        <div className="stat-card">
          <h3>Completed</h3>
          <div className="value" style={{ color: '#065f46' }}>{totalCompleted}</div>
        </div>
        <div className="stat-card">
          <h3>Pending</h3>
          <div className="value" style={{ color: '#92400e' }}>{totalPending}</div>
        </div>
      </div>

      <div className="card">
        <div className="flex items-center mb-4">
          <h2>Worker Status Overview</h2>
          <button className="btn btn-secondary btn-sm ml-auto" onClick={loadData}>Refresh</button>
        </div>

        {users.filter(u => u.role === 'worker').length === 0 ? (
          <p className="text-muted">No workers yet. <Link to="/users/new">Create one</Link>.</p>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Worker</th>
                <th>Checkpoints</th>
                <th>Pending</th>
                <th>Completed</th>
                <th>Last Update</th>
              </tr>
            </thead>
            <tbody>
              {users.filter(u => u.role === 'worker').map(u => (
                <tr key={u.id}>
                  <td><strong>{u.display_name}</strong><br /><span className="text-sm text-muted">@{u.username}</span></td>
                  <td>{u.checkpoints.length}</td>
                  <td><span className="status-badge status-pending">{u.pendingCount}</span></td>
                  <td><span className="status-badge status-completed">{u.completedCount}</span></td>
                  <td className="text-sm text-muted">{u.lastUpdated ? new Date(u.lastUpdated).toLocaleString() : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
