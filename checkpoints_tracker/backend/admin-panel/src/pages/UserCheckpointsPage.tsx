import { useEffect, useState, useRef } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { api } from '../api/client';
import type { Checkpoint, User } from '../types';
import { getFreshness } from '../utils/freshness';

interface CsvRow {
  label: string;
  lat: number;
  lng: number;
}

declare const L: any;

export default function UserCheckpointsPage() {
  const { userId } = useParams();
  const navigate = useNavigate();

  const [user, setUser] = useState<User | null>(null);
  const [checkpoints, setCheckpoints] = useState<Checkpoint[]>([]);
  const [loading, setLoading] = useState(true);
  const [liveLocation, setLiveLocation] = useState<{ latitude: number; longitude: number; updated_at: string } | null>(null);
  const [trail, setTrail] = useState<{ latitude: number; longitude: number }[]>([]);
  const mapRef = useRef<any>(null);
  const markersRef = useRef<any[]>([]);
  const trailLineRef = useRef<any>(null);
  const initialFitDone = useRef(false);
  const containerId = `usermap-${userId}`;

  // Add dialog
  const [showAdd, setShowAdd] = useState(false);
  const [addLabel, setAddLabel] = useState('');
  const [addLat, setAddLat] = useState('');
  const [addLng, setAddLng] = useState('');
  const [adding, setAdding] = useState(false);
  const [addError, setAddError] = useState('');

  // CSV dialog
  const [csvRows, setCsvRows] = useState<CsvRow[]>([]);
  const [csvChecked, setCsvChecked] = useState<Set<number>>(new Set());
  const [showCsv, setShowCsv] = useState(false);
  const [importing, setImporting] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  const loadData = async () => {
    try {
      const [userRes, cpRes] = await Promise.all([
        api.get<{ user: User }>(`/users/${userId}`),
        api.get<{ checkpoints: Checkpoint[] }>(`/checkpoints?user_id=${userId}`),
      ]);
      setUser(userRes.user);
      setCheckpoints(cpRes.checkpoints);
    } catch {
      navigate('/users');
    } finally {
      setLoading(false);
    }
  };

  const loadTrail = async () => {
    try {
      const [locRes, trailRes] = await Promise.all([
        api.get<{ location: { latitude: number; longitude: number; updated_at: string } | null }>(`/users/${userId}/location`),
        api.get<{ points: { latitude: number; longitude: number; created_at: string }[] }>(`/location/trail/${userId}`),
      ]);
      setLiveLocation(locRes.location);
      setTrail(trailRes.points);
    } catch {}
  };

  useEffect(() => { loadData(); loadTrail(); }, [userId]);

  // Auto-refresh map every 10s
  useEffect(() => {
    const interval = setInterval(loadTrail, 10000);
    return () => clearInterval(interval);
  }, [userId]);

  // ── Add dialog ────────────────────────────────────────

  const openAdd = () => {
    setAddLabel('');
    setAddLat(user?.latitude != null ? String(user.latitude) : '');
    setAddLng(user?.longitude != null ? String(user.longitude) : '');
    setAddError('');
    setShowAdd(true);
  };

  const handleAdd = async () => {
    if (!addLabel.trim()) { setAddError('Label is required'); return; }
    const lat = parseFloat(addLat);
    const lng = parseFloat(addLng);
    if (isNaN(lat) || isNaN(lng)) { setAddError('Valid lat/lng required'); return; }

    setAdding(true);
    setAddError('');
    try {
      await api.post('/checkpoints', { user_id: Number(userId), label: addLabel.trim(), latitude: lat, longitude: lng });
      setShowAdd(false);
      loadData();
    } catch (err) {
      setAddError(err instanceof Error ? err.message : 'Failed');
    } finally {
      setAdding(false);
    }
  };

  const handleDelete = async (id: number, label: string) => {
    if (!confirm(`Delete checkpoint "${label}"?`)) return;
    try {
      await api.delete(`/checkpoints/${id}`);
      setCheckpoints(prev => prev.filter(c => c.id !== id));
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Delete failed');
    }
  };

  // ── CSV dialog ─────────────────────────────────────────

  const handleCsvFile = (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (!f) return;

    const reader = new FileReader();
    reader.onload = (evt) => {
      const text = evt.target?.result as string;
      const lines = text.split('\n').filter(l => l.trim());
      if (lines.length < 2) { alert('File has no data rows'); return; }

      const headers = lines[0].split(',').map(h => h.trim().toLowerCase());
      const labelIdx = headers.indexOf('label');
      const latIdx = headers.indexOf('latitude');
      const lngIdx = headers.indexOf('longitude');
      if (labelIdx === -1 || latIdx === -1 || lngIdx === -1) { alert('CSV must have columns: label, latitude, longitude'); return; }

      const rows: CsvRow[] = [];
      for (let i = 1; i < lines.length; i++) {
        const cols = lines[i].split(',').map(c => c.trim());
        const label = cols[labelIdx];
        const lat = parseFloat(cols[latIdx]);
        const lng = parseFloat(cols[lngIdx]);
        if (label && !isNaN(lat) && !isNaN(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
          rows.push({ label, lat, lng });
        }
      }
      if (rows.length === 0) { alert('No valid rows found in CSV'); return; }

      setCsvRows(rows);
      setCsvChecked(new Set(rows.map((_, i) => i)));
      setShowCsv(true);
    };
    reader.readAsText(f);
    // Reset file input so same file can be re-selected
    e.target.value = '';
  };

  const toggleCsvRow = (idx: number) => {
    setCsvChecked(prev => {
      const next = new Set(prev);
      if (next.has(idx)) next.delete(idx); else next.add(idx);
      return next;
    });
  };

  const handleCsvImport = async () => {
    const selected = csvRows.filter((_, i) => csvChecked.has(i));
    if (selected.length === 0) { alert('No rows selected'); return; }

    setImporting(true);
    let imported = 0;
    let failed = 0;

    for (const row of selected) {
      try {
        await api.post('/checkpoints', {
          user_id: Number(userId),
          label: row.label,
          latitude: row.lat,
          longitude: row.lng,
        });
        imported++;
      } catch {
        failed++;
      }
    }

    setImporting(false);
    setShowCsv(false);
    alert(`${imported} checkpoints added${failed ? `, ${failed} failed` : ''}.`);
    loadData();
  };

  // Init map (runs after loading is done and element is in DOM)
  useEffect(() => {
    if (mapRef.current || loading) return;
    const el = document.getElementById(containerId);
    if (!el) return;
    const map = L.map(containerId).setView([33.6844, 73.0479], 13);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map);
    mapRef.current = map;
    return () => { map.remove(); mapRef.current = null; };
  }, [loading, userId]);

  // Update markers + trail on map
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !user) return;

    markersRef.current.forEach(m => map.removeLayer(m));
    markersRef.current = [];
    if (trailLineRef.current) { map.removeLayer(trailLineRef.current); trailLineRef.current = null; }

    const bounds: number[][] = [];

    // Checkpoint pins
    checkpoints.forEach(cp => {
      const color = cp.status === 'completed' ? '#10b981' : '#f59e0b';
      const m = L.circleMarker([cp.latitude, cp.longitude], {
        radius: 7, fillColor: color, color: '#fff', weight: 2, fillOpacity: 0.9,
      }).addTo(map);
      m.bindPopup(`<b>${cp.label}</b><br/>${cp.status}<br/>${cp.latitude.toFixed(6)}, ${cp.longitude.toFixed(6)}`);
      markersRef.current.push(m);
      bounds.push([cp.latitude, cp.longitude]);
    });

    // Live location — pin with a pulsing ripple when the data is actually fresh
    if (liveLocation) {
      const isLive = getFreshness(liveLocation.updated_at) === 'live';
      const color = '#2563eb';
      const ripples = isLive
        ? `<span class="ripple r1" style="background:${color}"></span><span class="ripple r2" style="background:${color}"></span><span class="ripple r3" style="background:${color}"></span>`
        : '';
      const icon = L.divIcon({
        className: '',
        html: `<div class="live-marker">${ripples}<svg class="pin-svg" width="20" height="26" viewBox="0 0 24 30"><path fill="${color}" d="M12 0C6.5 0 2 4.5 2 10c0 7.5 10 19 10 19s10-11.5 10-19c0-5.5-4.5-10-10-10z"/><circle cx="12" cy="10" r="4" fill="#fff"/></svg></div>`,
        iconSize: [24, 32],
        iconAnchor: [12, 29],
      });
      const m = L.marker([liveLocation.latitude, liveLocation.longitude], { icon }).addTo(map);
      m.bindPopup(`<b>${user.display_name}</b><br/>${isLive ? 'Live' : 'Last known'}<br/>${new Date(liveLocation.updated_at).toLocaleTimeString()}`);
      markersRef.current.push(m);
      bounds.push([liveLocation.latitude, liveLocation.longitude]);
    }

    // GPS trail
    if (trail.length > 1) {
      const coords = trail.map(p => [p.latitude, p.longitude]);
      trailLineRef.current = L.polyline(coords, { color: '#2563eb', weight: 3, opacity: 0.6 }).addTo(map);
      bounds.push(...coords);
    }

    // Add assigned checkpoint location as green marker
    if (user.latitude != null && user.longitude != null) {
      const m = L.marker([user.latitude, user.longitude]).addTo(map);
      m.bindPopup(`<b>${user.display_name}'s assigned location</b>`);
      markersRef.current.push(m);
      bounds.push([user.latitude, user.longitude]);
    }

    if (bounds.length > 0 && !initialFitDone.current) {
      map.fitBounds(bounds, { padding: [50, 50] });
      initialFitDone.current = true;
    }
  }, [checkpoints, liveLocation, trail]);

  if (loading) return <div style={{ padding: '2rem', textAlign: 'center' }}>Loading...</div>;
  if (!user) return null;

  return (
    <div>
      {/* ── Header ─────────────────────────────────────── */}
      <div className="flex items-center mb-4">
        <button className="btn btn-secondary btn-sm" onClick={() => navigate('/users')}>← All Users</button>
        <h2 style={{ marginLeft: '1rem', flex: 1 }}>
          {user.display_name} (@{user.username})
        </h2>
        <button className="btn btn-primary btn-sm" onClick={openAdd}>+ Add Checkpoint</button>
        <button className="btn btn-secondary btn-sm" style={{ marginLeft: 8 }} onClick={() => fileRef.current?.click()}>
          Import CSV
        </button>
        <input type="file" accept=".csv" ref={fileRef} onChange={handleCsvFile} style={{ display: 'none' }} />
      </div>

      {/* ── Live Map ──────────────────────────────────────── */}
      <div className="card mb-2">
        <div className="flex items-center mb-2">
          <h3>Live Location</h3>
          <span className="text-sm text-muted ml-auto">
            {liveLocation ? `Last update: ${new Date(liveLocation.updated_at).toLocaleTimeString()}` : 'No location data yet'}
          </span>
        </div>
        <div id={containerId} style={{ height: '300px', borderRadius: 6 }} />
        {trail.length > 0 && (
          <p className="text-sm text-muted mt-2" style={{ marginTop: 8 }}>{trail.length} tracking points collected</p>
        )}
      </div>

      {/* ── Checkpoint list ──────────────────────────────── */}
      <div className="card">
        <h3 className="mb-2">Checkpoints ({checkpoints.length})</h3>
        <table>
          <thead>
            <tr>
              <th>Label</th>
              <th>Latitude</th>
              <th>Longitude</th>
              <th>Status</th>
              <th>Completed</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {checkpoints.map(c => (
              <tr key={c.id}>
                <td><strong>{c.label}</strong></td>
                <td className="text-sm">{c.latitude.toFixed(6)}</td>
                <td className="text-sm">{c.longitude.toFixed(6)}</td>
                <td>
                  <span className={`status-badge ${c.status === 'completed' ? 'status-completed' : 'status-pending'}`}>
                    {c.status}
                  </span>
                </td>
                <td className="text-sm text-muted">
                  {c.completed_at ? new Date(c.completed_at).toLocaleString() : '—'}
                </td>
                <td>
                  <button className="btn btn-danger btn-sm" onClick={() => handleDelete(c.id, c.label)}>Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* ── Add dialog ─────────────────────────────────── */}
      {showAdd && (
        <div className="modal-overlay" onClick={() => setShowAdd(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <h3 className="mb-2">Add Checkpoint</h3>
            {addError && <div className="error-msg mb-2">{addError}</div>}
            <div className="form-group">
              <label>Label</label>
              <input type="text" value={addLabel} onChange={e => setAddLabel(e.target.value)} placeholder="e.g. Gate 3 – Site A" autoFocus />
            </div>
            <div className="form-group">
              <label>Latitude</label>
              <input type="number" step="any" value={addLat} onChange={e => setAddLat(e.target.value)} />
            </div>
            <div className="form-group">
              <label>Longitude</label>
              <input type="number" step="any" value={addLng} onChange={e => setAddLng(e.target.value)} />
            </div>
            <div className="flex gap-2" style={{ justifyContent: 'flex-end' }}>
              <button className="btn btn-secondary" onClick={() => setShowAdd(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleAdd} disabled={adding}>
                {adding ? 'Adding...' : 'Add'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── CSV dialog ──────────────────────────────────── */}
      {showCsv && (
        <div className="modal-overlay" onClick={() => setShowCsv(false)}>
          <div className="modal modal-wide" onClick={e => e.stopPropagation()}>
            <h3 className="mb-2">Import Checkpoints from CSV</h3>
            <p className="text-sm text-muted mb-2">
              Select rows to import for <strong>{user.display_name}</strong>.
            </p>
            <table className="mb-2">
              <thead>
                <tr>
                  <th style={{ width: 40 }}>
                    <input
                      type="checkbox"
                      checked={csvChecked.size === csvRows.length}
                      onChange={() => {
                        if (csvChecked.size === csvRows.length) setCsvChecked(new Set());
                        else setCsvChecked(new Set(csvRows.map((_, i) => i)));
                      }}
                    />
                  </th>
                  <th>Label</th>
                  <th>Latitude</th>
                  <th>Longitude</th>
                </tr>
              </thead>
              <tbody>
                {csvRows.map((r, i) => (
                  <tr key={i} onClick={() => toggleCsvRow(i)} style={{ cursor: 'pointer' }}>
                    <td><input type="checkbox" checked={csvChecked.has(i)} onChange={() => toggleCsvRow(i)} /></td>
                    <td>{r.label}</td>
                    <td>{r.lat}</td>
                    <td>{r.lng}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div className="flex gap-2" style={{ justifyContent: 'flex-end' }}>
              <button className="btn btn-secondary" onClick={() => setShowCsv(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleCsvImport} disabled={importing || csvChecked.size === 0}>
                {importing ? 'Importing...' : `Import ${csvChecked.size} Selected`}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
