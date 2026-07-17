import { useEffect, useState } from 'react';
import { api } from '../api/client';
import type { User, Checkpoint, WorkerLocation } from '../types';
import { Link } from 'react-router-dom';
import { getFreshness, relativeTime, FRESHNESS_LABEL } from '../utils/freshness';
import { useNowTick } from '../hooks/useNowTick';

interface UserWithCheckpoints extends User {
  checkpoints: Checkpoint[];
  pendingCount: number;
  completedCount: number;
  locationUpdatedAt: string | null;
}

const REFRESH_INTERVAL_MS = 15_000;

export default function DashboardPage() {
  const [users, setUsers] = useState<UserWithCheckpoints[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  useNowTick();

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

      const usersWithCp: UserWithCheckpoints[] = userRes.users.map(u => {
        const userCps = cpRes.checkpoints.filter(c => c.user_id === u.id);
        return {
          ...u,
          checkpoints: userCps,
          pendingCount: userCps.filter(c => c.status === 'pending').length,
          completedCount: userCps.filter(c => c.status === 'completed').length,
          locationUpdatedAt: locationByUserId.get(u.id)?.updated_at ?? null,
        };
      });

      setUsers(usersWithCp);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load data');
    } finally {
      setLoading(false);
    }
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

  const totalWorkers = users.filter(u => u.role === 'worker').length;
  const totalCheckpoints = users.reduce((s, u) => s + u.checkpoints.length, 0);
  const totalCompleted = users.reduce((s, u) => s + u.completedCount, 0);
  const totalPending = totalCheckpoints - totalCompleted;
  const totalOffline = users.filter(
    u => u.role === 'worker' && (u.location_service_enabled === 0 || getFreshness(u.locationUpdatedAt) === 'offline')
  ).length;

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
        <div className="stat-card">
          <h3>Offline Workers</h3>
          <div className="value" style={{ color: totalOffline > 0 ? '#dc2626' : undefined }}>{totalOffline}</div>
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
                <th>Tracking</th>
                <th>Checkpoints</th>
                <th>Pending</th>
                <th>Completed</th>
                <th>Last Location Ping</th>
                <th>Alarm</th>
              </tr>
            </thead>
            <tbody>
              {users.filter(u => u.role === 'worker').map(u => {
                const locationOff = u.location_service_enabled === 0;
                const freshness = getFreshness(u.locationUpdatedAt);
                return (
                  <tr key={u.id}>
                    <td><strong>{u.display_name}</strong><br /><span className="text-sm text-muted">@{u.username}</span></td>
                    <td>
                      {locationOff ? (
                        <span className="badge badge-offline" title={u.location_service_updated_at ? `Device reported location off ${relativeTime(u.location_service_updated_at)}` : 'Device reported location off'}>
                          <span className="freshness-dot offline" />
                          Location Off
                        </span>
                      ) : (
                        <span className={`badge badge-${freshness}`}>
                          <span className={`freshness-dot ${freshness}`} />
                          {FRESHNESS_LABEL[freshness]}
                        </span>
                      )}
                    </td>
                    <td>{u.checkpoints.length}</td>
                    <td><span className="badge badge-pending">{u.pendingCount}</span></td>
                    <td><span className="badge badge-completed">{u.completedCount}</span></td>
                    <td className="text-sm text-muted">{relativeTime(u.locationUpdatedAt)}</td>
                    <td>
                      <label className="toggle-switch" title="Ring loud alarm if location is turned off">
                        <input
                          type="checkbox"
                          checked={Boolean(u.alarm_enabled)}
                          onChange={e => handleToggleAlarm(u.id, e.target.checked)}
                        />
                        <span className="slider" />
                      </label>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
