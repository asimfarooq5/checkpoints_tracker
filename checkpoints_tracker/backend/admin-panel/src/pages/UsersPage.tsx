import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api/client';
import type { User, Checkpoint, WorkerLocation } from '../types';
import { getFreshness, relativeTime, FRESHNESS_LABEL } from '../utils/freshness';

interface UserWithStats extends User {
  pendingCount: number;
  completedCount: number;
  locationUpdatedAt: string | null;
}

const REFRESH_INTERVAL_MS = 30_000;

function initials(name: string) {
  return name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2);
}

export default function UsersPage() {
  const [users, setUsers] = useState<UserWithStats[]>([]);
  const [loading, setLoading] = useState(true);
  const navigate = useNavigate();

  useEffect(() => {
    loadData();
    const interval = setInterval(loadData, REFRESH_INTERVAL_MS);
    return () => clearInterval(interval);
  }, []);

  const loadData = async () => {
    try {
      const [userRes, cpRes, locRes] = await Promise.all([
        api.get<{ users: User[] }>('/users'),
        api.get<{ checkpoints: Checkpoint[] }>('/checkpoints'),
        api.get<{ workers: WorkerLocation[] }>('/locations'),
      ]);
      const locationByUserId = new Map(locRes.workers.map(w => [w.id, w.location]));
      setUsers(userRes.users.map(u => {
        const cps = cpRes.checkpoints.filter(c => c.user_id === u.id);
        return {
          ...u,
          pendingCount: cps.filter(c => c.status === 'pending').length,
          completedCount: cps.filter(c => c.status === 'completed').length,
          locationUpdatedAt: locationByUserId.get(u.id)?.updated_at ?? null,
        };
      }));
    } catch {} finally { setLoading(false); }
  };

  const handleDelete = async (id: number, name: string) => {
    if (!confirm(`Delete user "${name}" and all their checkpoints?`)) return;
    try {
      await api.delete(`/users/${id}`);
      setUsers(prev => prev.filter(u => u.id !== id));
    } catch (err) { alert(err instanceof Error ? err.message : 'Delete failed'); }
  };

  const handleToggleAlarm = async (id: number, next: boolean) => {
    setUsers(prev => prev.map(u => (u.id === id ? { ...u, alarm_enabled: next ? 1 : 0 } : u)));
    try {
      await api.put(`/users/${id}`, { alarm_enabled: next ? 1 : 0 });
    } catch (err) {
      setUsers(prev => prev.map(u => (u.id === id ? { ...u, alarm_enabled: next ? 0 : 1 } : u)));
      alert(err instanceof Error ? err.message : 'Failed to update alarm');
    }
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Users</h1>
          <p className="subtitle">{users.filter(u => u.role === 'worker').length} workers · {users.length} total</p>
        </div>
        <button className="btn btn-primary" onClick={() => navigate('/users/new')}>+ New User</button>
      </div>

      <div className="card" style={{ padding: 0 }}>
        <div className="table-container">
          {loading ? (
            <div style={{ padding: '2rem', textAlign: 'center', color: 'var(--gray-400)' }}>Loading users...</div>
          ) : users.length === 0 ? (
            <div className="empty-state">
              <div className="icon">👤</div>
              <p>No users yet. Create your first one.</p>
            </div>
          ) : (
            <table>
              <thead>
                <tr>
                  <th>User</th>
                  <th>Role</th>
                  <th>Checkpoints</th>
                  <th>Tracking</th>
                  <th>Location</th>
                  <th>Alarm</th>
                  <th>Created</th>
                  <th style={{ width: 120 }}></th>
                </tr>
              </thead>
              <tbody>
                {users.map(u => (
                  <tr key={u.id} className="clickable" onClick={() => navigate(u.role === 'worker' ? `/users/${u.id}/checkpoints` : `/users/${u.id}/edit`)}>
                    <td>
                      <div className="user-cell">
                        <div className="user-avatar">{initials(u.display_name)}</div>
                        <div>
                          <div className="name">{u.display_name}</div>
                          <div className="username">@{u.username}</div>
                        </div>
                      </div>
                    </td>
                    <td><span className={`badge ${u.role === 'admin' ? 'badge-admin' : 'badge-worker'}`}>{u.role}</span></td>
                    <td>
                      {u.role === 'worker' ? (
                        <div className="flex gap-1 items-center">
                          <span className="badge badge-pending">{u.pendingCount} pending</span>
                          <span className="badge badge-completed">{u.completedCount} done</span>
                        </div>
                      ) : <span className="text-muted text-sm">—</span>}
                    </td>
                    <td>
                      {u.role === 'worker' ? (() => {
                        const freshness = getFreshness(u.locationUpdatedAt);
                        return (
                          <span className={`badge badge-${freshness}`} title={relativeTime(u.locationUpdatedAt)}>
                            <span className={`freshness-dot ${freshness}`} />
                            {FRESHNESS_LABEL[freshness]}
                          </span>
                        );
                      })() : <span className="text-muted text-sm">—</span>}
                    </td>
                    <td className="text-sm text-muted">
                      {u.latitude != null && u.longitude != null
                        ? `${u.latitude.toFixed(4)}, ${u.longitude.toFixed(4)}`
                        : '—'}
                    </td>
                    <td onClick={e => e.stopPropagation()}>
                      {u.role === 'worker' ? (
                        <label style={{ display: 'flex', alignItems: 'center', cursor: 'pointer' }} title="Ring loud alarm if location is turned off">
                          <input
                            type="checkbox"
                            checked={Boolean(u.alarm_enabled)}
                            onChange={e => handleToggleAlarm(u.id, e.target.checked)}
                          />
                        </label>
                      ) : <span className="text-muted text-sm">—</span>}
                    </td>
                    <td className="text-sm text-muted">{new Date(u.created_at).toLocaleDateString()}</td>
                    <td>
                      <div className="flex gap-1" onClick={e => e.stopPropagation()}>
                        {u.role === 'worker' && (
                          <button className="btn btn-primary btn-xs" onClick={() => navigate(`/users/${u.id}/checkpoints`)}>Manage</button>
                        )}
                        <button className="btn btn-secondary btn-xs" onClick={() => navigate(`/users/${u.id}/edit`)}>Edit</button>
                        {u.role !== 'admin' && (
                          <button className="btn btn-danger btn-xs" onClick={() => handleDelete(u.id, u.display_name)}>Del</button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
