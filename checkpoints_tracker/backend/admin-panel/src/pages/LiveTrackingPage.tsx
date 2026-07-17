import { useEffect, useState, useRef } from 'react';
import { api } from '../api/client';
import { segmentTrail, type TrailSegment } from '../utils/geo';
import { getFreshness } from '../utils/freshness';
import { useNowTick } from '../hooks/useNowTick';

function easeInOutQuad(t: number) {
  return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
}

// Glides a marker from its current position to a new one instead of snapping,
// so a live-updating worker's dot visibly moves on the map.
function animateMarkerTo(marker: any, from: [number, number], to: [number, number], duration = 800) {
  const start = performance.now();
  function step(now: number) {
    const t = Math.min((now - start) / duration, 1);
    const e = easeInOutQuad(t);
    marker.setLatLng([from[0] + (to[0] - from[0]) * e, from[1] + (to[1] - from[1]) * e]);
    if (t < 1) requestAnimationFrame(step);
  }
  requestAnimationFrame(step);
}

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
  const [clearing, setClearing] = useState(false);
  const mapRef = useRef<any>(null);
  const markersRef = useRef<Map<number, any>>(new Map());
  const lastLatLngRef = useRef<Map<number, [number, number]>>(new Map());
  const trailLayersRef = useRef<any[]>([]);
  const containerId = 'livemap';
  const initialFitDone = useRef(false);
  const nowTick = useNowTick();

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

  const segments: TrailSegment[] = segmentTrail(trail);

  // Update markers and trail on map
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;

    trailLayersRef.current.forEach(l => map.removeLayer(l));
    trailLayersRef.current = [];

    const bounds: number[][] = [];

    // Markers persist across updates (keyed by worker id) instead of being
    // destroyed and recreated, so a live worker's dot can glide to its new
    // position instead of popping there. Stale/offline workers snap instead —
    // animating a marker toward data that might be minutes old is misleading.
    // Live workers also get a pulsing ripple ring (only live ones — a ripple
    // on stale data would falsely suggest the worker is actively moving now).
    workers.forEach(w => {
      if (!w.location) return;
      const lat = w.location.latitude;
      const lng = w.location.longitude;
      bounds.push([lat, lng]);

      const isLive = getFreshness(w.location.updated_at) === 'live';
      const prev = lastLatLngRef.current.get(w.id);
      const color = selectedId === String(w.id) ? '#2563eb' : '#f59e0b';
      const popupHtml = `<b>${w.display_name}</b><br/>@${w.username}<br/>${new Date(w.location.updated_at).toLocaleTimeString()}`;
      const ripples = isLive
        ? `<span class="ripple r1" style="background:${color}"></span><span class="ripple r2" style="background:${color}"></span><span class="ripple r3" style="background:${color}"></span>`
        : '';
      const icon = L.divIcon({
        className: '',
        html: `<div class="live-marker">${ripples}<svg class="pin-svg" width="20" height="26" viewBox="0 0 24 30"><path fill="${color}" d="M12 0C6.5 0 2 4.5 2 10c0 7.5 10 19 10 19s10-11.5 10-19c0-5.5-4.5-10-10-10z"/><circle cx="12" cy="10" r="4" fill="#fff"/></svg></div>`,
        iconSize: [24, 32],
        iconAnchor: [12, 29],
      });

      let marker = markersRef.current.get(w.id);
      if (!marker) {
        marker = L.marker([lat, lng], { icon }).addTo(map);
        marker.bindPopup(popupHtml);
        markersRef.current.set(w.id, marker);
      } else {
        marker.setIcon(icon);
        marker.setPopupContent(popupHtml);
        const moved = !prev || prev[0] !== lat || prev[1] !== lng;
        if (moved) {
          if (isLive && prev) {
            animateMarkerTo(marker, prev, [lat, lng]);
          } else {
            marker.setLatLng([lat, lng]);
          }
        }
      }
      lastLatLngRef.current.set(w.id, [lat, lng]);
    });

    // Drop markers for workers no longer in the list
    const currentIds = new Set(workers.map(w => w.id));
    markersRef.current.forEach((marker, id) => {
      if (!currentIds.has(id)) {
        map.removeLayer(marker);
        markersRef.current.delete(id);
        lastLatLngRef.current.delete(id);
      }
    });

    // Draw route/idle segments for the selected worker
    segments.forEach(seg => {
      if (seg.type === 'route') {
        const coords = seg.points.map(p => [p.latitude, p.longitude]);
        if (coords.length < 2) return;
        const line = L.polyline(coords, { color: '#2563eb', weight: 3, opacity: 0.75 }).addTo(map);
        trailLayersRef.current.push(line);
        bounds.push(...coords);
      } else {
        const hours = Math.floor(seg.durationMin / 60);
        const mins = Math.round(seg.durationMin % 60);
        const durationLabel = hours > 0 ? `${hours}h ${mins}m` : `${mins}m`;
        const circle = L.circleMarker([seg.latitude, seg.longitude], {
          radius: 12,
          fillColor: '#f97316',
          color: '#fff',
          weight: 2,
          fillOpacity: 0.85,
        }).addTo(map);
        circle.bindPopup(`Idle ${durationLabel} here`);
        trailLayersRef.current.push(circle);
        bounds.push([seg.latitude, seg.longitude]);
      }
    });

    if (bounds.length > 0 && !initialFitDone.current) {
      map.fitBounds(bounds, { padding: [50, 50] });
      initialFitDone.current = true;
    }
  }, [workers, segments, selectedId, nowTick]);

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

  const handleClearPath = async () => {
    if (!selectedId) return;
    const worker = workers.find(w => String(w.id) === selectedId);
    if (!confirm(`Clear all location history for ${worker?.display_name ?? 'this worker'}? This cannot be undone.`)) return;
    setClearing(true);
    try {
      await api.delete(`/location/trail/${selectedId}`);
      setTrail([]);
      const res = await api.get<{ workers: WorkerLocation[] }>('/locations');
      setWorkers(res.workers);
    } catch (err) {
      alert(err instanceof Error ? err.message : 'Failed to clear path');
    } finally {
      setClearing(false);
    }
  };

  // The side panel toggling changes the map container's width; Leaflet needs
  // an explicit nudge or it keeps rendering at the old size until resize.
  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;
    const timer = setTimeout(() => map.invalidateSize(), 0);
    return () => clearTimeout(timer);
  }, [selectedId]);

  return (
    <div>
      <div className="card mb-2">
        <div className="flex items-center mb-2" style={{ gap: '0.75rem' }}>
          <h2>Live Tracking</h2>
          <select
            value={selectedId}
            onChange={e => handleSelect(e.target.value)}
            style={{ padding: '0.3rem 0.5rem', borderRadius: 6, border: '1px solid #d1d5db' }}
          >
            <option value="">All workers</option>
            {workers.map(w => (
              <option key={w.id} value={w.id}>
                {w.display_name} (@{w.username}) {w.location ? '🟢' : '⚫'}
              </option>
            ))}
          </select>
          {selectedId && (
            <button className="btn btn-danger btn-sm" onClick={handleClearPath} disabled={clearing}>
              {clearing ? 'Clearing...' : 'Clear Path'}
            </button>
          )}
          <span className="text-sm text-muted ml-auto">Auto-refreshes every 10s</span>
        </div>
      </div>
      <div style={{ display: 'flex', gap: '0.75rem', height: 'calc(100vh - 200px)' }}>
        <div id={containerId} style={{ flex: 1, borderRadius: 8, boxShadow: '0 1px 3px rgba(0,0,0,0.1)' }} />
        {selectedId && (
          <div className="card" style={{ width: 320, flexShrink: 0, padding: 0, display: 'flex', flexDirection: 'column' }}>
            <div style={{ padding: '0.75rem 1rem', borderBottom: '1px solid var(--gray-200, #e5e7eb)' }}>
              <strong>Route Breakdown</strong>
              <div className="text-xs text-muted">{trail.length} point{trail.length === 1 ? '' : 's'}</div>
            </div>
            <div style={{ overflowY: 'auto', flex: 1 }}>
              {segments.length === 0 ? (
                <div className="text-sm text-muted" style={{ padding: '1rem' }}>No location pings yet.</div>
              ) : (
                segments.map((seg, i) => (
                  <div key={i} style={{ padding: '0.6rem 1rem', borderBottom: '1px solid var(--gray-100, #f3f4f6)', fontSize: '0.8rem' }}>
                    {seg.type === 'route' ? (
                      <>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 600 }}>
                          <span style={{ width: 10, height: 10, borderRadius: '50%', background: '#2563eb', display: 'inline-block' }} />
                          {seg.label}
                        </div>
                        <div className="text-muted">
                          {seg.points.length} points · {new Date(seg.points[0].created_at).toLocaleTimeString()} – {new Date(seg.points[seg.points.length - 1].created_at).toLocaleTimeString()}
                        </div>
                      </>
                    ) : (
                      <>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 600 }}>
                          <span style={{ width: 10, height: 10, borderRadius: '50%', background: '#f97316', display: 'inline-block' }} />
                          Idle {seg.durationMin >= 60 ? `${Math.floor(seg.durationMin / 60)}h ${Math.round(seg.durationMin % 60)}m` : `${Math.round(seg.durationMin)}m`}
                        </div>
                        <div className="text-muted">
                          {new Date(seg.startTime).toLocaleTimeString()} – {new Date(seg.endTime).toLocaleTimeString()}
                        </div>
                      </>
                    )}
                  </div>
                ))
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
