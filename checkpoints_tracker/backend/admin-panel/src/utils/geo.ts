export function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export interface GeoPoint {
  latitude: number;
  longitude: number;
  created_at: string;
}

export interface RouteSegment {
  type: 'route';
  label: string;
  points: GeoPoint[];
}

export interface IdleSegment {
  type: 'idle';
  points: GeoPoint[];
  startTime: string;
  endTime: string;
  durationMin: number;
  latitude: number;
  longitude: number;
}

export type TrailSegment = RouteSegment | IdleSegment;

const IDLE_RADIUS_M = 50;
const IDLE_MIN_MINUTES = 30;

// Splits a chronological trail into "route" segments (active movement) and "idle"
// segments (stayed within IDLE_RADIUS_M for at least IDLE_MIN_MINUTES). Idle segments
// share their boundary point with the adjacent route segments so the drawn lines
// connect without visual gaps.
export function segmentTrail(points: GeoPoint[]): TrailSegment[] {
  const segments: TrailSegment[] = [];
  let currentRoute: GeoPoint[] = [];
  let routeCount = 0;
  let i = 0;

  const flushRoute = () => {
    if (currentRoute.length > 1) {
      routeCount++;
      segments.push({ type: 'route', label: `Route ${routeCount}`, points: currentRoute });
    }
  };

  while (i < points.length) {
    const anchor = points[i];
    let j = i;
    while (
      j + 1 < points.length &&
      haversineMeters(anchor.latitude, anchor.longitude, points[j + 1].latitude, points[j + 1].longitude) <= IDLE_RADIUS_M
    ) {
      j++;
    }
    const spanMin = (new Date(points[j].created_at).getTime() - new Date(points[i].created_at).getTime()) / 60000;

    if (spanMin >= IDLE_MIN_MINUTES) {
      currentRoute.push(anchor);
      flushRoute();
      segments.push({
        type: 'idle',
        points: points.slice(i, j + 1),
        startTime: points[i].created_at,
        endTime: points[j].created_at,
        durationMin: spanMin,
        latitude: anchor.latitude,
        longitude: anchor.longitude,
      });
      currentRoute = [points[j]];
      i = j + 1;
    } else {
      currentRoute.push(anchor);
      i++;
    }
  }
  flushRoute();

  return segments;
}
