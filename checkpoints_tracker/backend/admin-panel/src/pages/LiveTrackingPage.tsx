import { useEffect, useState, useRef } from 'react';
import { api } from '../api/client';

interface WorkerLocation {
  id: number;
  username: string;
  display_name: string;
  location: { latitude: number; longitude: number; updated_at: string } | null;
}

interface TrailPoint {
  latitude: number;
  longitude: number;
  created_at: string;
  checkpoint_id: number | null;
}

// Leaflet loaded from CDN in index.html
declare const L: any;

export default function LiveTrackingPage() {
  const [workers, setWorkers] = useState<WorkerLocation[]>([]);
  const [selectedId, setSelectedId] = useState<string>('');
  const [trail, setTrail] = useState<TrailPoint[]>([]);
  const mapRef = useRef<any>(null);
  const markersRef = useRef<any[]>([]);
  const trailLineRef = useRef<any>(null);
  const containerId = 'livemap';

  // Load workers
  useEffect(() => {
    api.get<{ workers: WorkerLocation[] }>('/locations').then(r => setWorkers(r.workers)).catch(() => {});
  }, []);

  // Init map
  useEffect(() => {
    if (mapRef.current) return;
    const map = L.map(containerId).setView([33.6844, 73.0479], 12);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map);
    mapRef.current = map;
    return () => { map.remove(); mapRef.current = null; };
  }, []);

  // Refresh locations every 10s
  useEffect(() => {
    const interval = setInterval(async () => {
      try {
        const res = await api.get<{ workers: WorkerLocation[] }>('/locations');
        setWorkers(res.workers);
        if (selectedId) {
          const trailRes = await api.get<{ points: TrailPoint[] }>(`/location/trail/${selectedId}`);
          setTrail(trailRes.points);
        }
      } catch {}
    }, 10000);
    return () => clearInterval(interval);
  }, [selectedId]);

  // Update markers and trail on map
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    // Clear old markers
    markersRef.current.forEach(m => map.removeLayer(m));
    markersRef.current = [];

    const bounds: number[][] = [];

    workers.forEach(w => {
      if (!w.location) return;
      const lat = w.location.latitude;
      const lng = w.location.longitude;
      bounds.push([lat, lng]);

      const marker = L.circleMarker([lat, lng], {
        radius: 8,
        fillColor: selectedId === String(w.id) ? '#2563eb' : '#f59e0b',
        color: '#fff',
        weight: 2,
        fillOpacity: 0.9,
      }).addTo(map);

      marker.bindPopup(`<b>${w.display_name}</b><br/>@${w.username}<br/>${new Date(w.location.updated_at).toLocaleTimeString()}`);
      markersRef.current.push(marker);
    });

    // Draw trail for selected worker
    if (trailLineRef.current) { map.removeLayer(trailLineRef.current); trailLineRef.current = null; }
    if (trail.length > 1) {
      const coords = trail.map(p => [p.latitude, p.longitude]);
      trailLineRef.current = L.polyline(coords, { color: '#2563eb', weight: 3, opacity: 0.7 }).addTo(map);
      bounds.push(...coords);
    }

    if (bounds.length > 0) map.fitBounds(bounds, { padding: [50, 50] });
  }, [workers, trail, selectedId]);

  const handleSelect = async (id: string) => {
    setSelectedId(id);
    if (id) {
      try {
        const res = await api.get<{ points: TrailPoint[] }>(`/location/trail/${id}`);
        setTrail(res.points);
      } catch {}
    } else {
      setTrail([]);
    }
  };

  return (
    <div>
      <div className="card mb-2">
        <div className="flex items-center mb-2">
          <h2>Live Tracking</h2>
          <select
            value={selectedId}
            onChange={e => handleSelect(e.target.value)}
            style={{ marginLeft: '1rem', padding: '0.3rem 0.5rem', borderRadius: 6, border: '1px solid #d1d5db' }}
          >
            <option value="">All workers</option>
            {workers.map(w => (
              <option key={w.id} value={w.id}>
                {w.display_name} (@{w.username}) {w.location ? '🟢' : '⚫'}
              </option>
            ))}
          </select>
          <span className="text-sm text-muted ml-auto">Auto-refreshes every 10s</span>
        </div>
      </div>
      <div id={containerId} style={{ height: 'calc(100vh - 200px)', borderRadius: 8, boxShadow: '0 1px 3px rgba(0,0,0,0.1)' }} />
    </div>
  );
}
