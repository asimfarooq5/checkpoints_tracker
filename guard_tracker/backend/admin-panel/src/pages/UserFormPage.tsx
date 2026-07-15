import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api } from '../api/client';
import type { User } from '../types';

export default function UserFormPage() {
  const { id } = useParams();
  const isEdit = Boolean(id);
  const navigate = useNavigate();

  const [form, setForm] = useState({ username: '', display_name: '', password: '', role: 'worker' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (id) {
      api.get<{ user: User }>(`/users/${id}`)
        .then(res => setForm({
          username: res.user.username,
          display_name: res.user.display_name,
          password: '',
          role: res.user.role,
        }))
        .catch(err => setError(err instanceof Error ? err.message : 'Failed to load user'));
    }
  }, [id]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      if (isEdit) {
        const body: Record<string, string> = {};
        if (form.username) body.username = form.username;
        if (form.display_name) body.display_name = form.display_name;
        if (form.password) body.password = form.password;
        if (form.role) body.role = form.role;
        await api.put(`/users/${id}`, body);
      } else {
        await api.post('/users', form);
      }
      navigate('/users');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Save failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <div className="card">
        <h2 className="mb-4">{isEdit ? 'Edit User' : 'New User'}</h2>
        {error && <div className="error-msg mb-4">{error}</div>}
        <form onSubmit={handleSubmit} style={{ maxWidth: '450px' }}>
          <div className="form-group">
            <label>Username</label>
            <input type="text" value={form.username} onChange={e => setForm({ ...form, username: e.target.value })} required={!isEdit} />
          </div>
          <div className="form-group">
            <label>Display Name</label>
            <input type="text" value={form.display_name} onChange={e => setForm({ ...form, display_name: e.target.value })} required />
          </div>
          <div className="form-group">
            <label>Password {isEdit && '(leave empty to keep current)'}</label>
            <input type="password" value={form.password} onChange={e => setForm({ ...form, password: e.target.value })} required={!isEdit} />
          </div>
          <div className="form-group">
            <label>Role</label>
            <select value={form.role} onChange={e => setForm({ ...form, role: e.target.value })}>
              <option value="worker">Worker</option>
              <option value="admin">Admin</option>
            </select>
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? 'Saving...' : 'Save'}
            </button>
            <button type="button" className="btn btn-secondary" onClick={() => navigate('/users')}>Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
}
