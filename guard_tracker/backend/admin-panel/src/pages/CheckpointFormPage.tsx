import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api } from '../api/client';
import type { Checkpoint } from '../types';

export default function CheckpointFormPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [label, setLabel] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    if (id) {
      api.get<{ checkpoint: Checkpoint }>(`/checkpoints/${id}`)
        .then(res => setLabel(res.checkpoint.label))
        .catch(err => setError(err instanceof Error ? err.message : 'Failed to load checkpoint'));
    }
  }, [id]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!label.trim()) return;
    setLoading(true);
    try {
      await api.put(`/checkpoints/${id}`, { label: label.trim() });
      navigate(-1);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Save failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <div className="card" style={{ maxWidth: '450px' }}>
        <h2 className="mb-4">Edit Checkpoint Label</h2>
        {error && <div className="error-msg mb-4">{error}</div>}
        <form onSubmit={handleSubmit}>
          <div className="form-group">
            <label>Label</label>
            <input type="text" value={label} onChange={e => setLabel(e.target.value)} required />
          </div>
          <div className="flex gap-2">
            <button type="submit" className="btn btn-primary" disabled={loading}>
              {loading ? 'Saving...' : 'Save'}
            </button>
            <button type="button" className="btn btn-secondary" onClick={() => navigate(-1)}>Cancel</button>
          </div>
        </form>
      </div>
    </div>
  );
}
