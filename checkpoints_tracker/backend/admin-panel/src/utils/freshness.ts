export type Freshness = 'live' | 'stale' | 'offline';

const LIVE_MS = 2 * 60 * 1000;
const STALE_MS = 15 * 60 * 1000;

// The backend stores timestamps via SQLite's datetime('now'), which is UTC
// formatted as "YYYY-MM-DD HH:MM:SS" with no timezone marker. `new Date()`
// on a string like that is parsed as *local* time by JS engines, not UTC —
// so every timestamp looked hours old (e.g. 5h in PKT) and everything showed
// as permanently "Offline" no matter how fresh the data actually was.
function parseServerTimestamp(ts: string): number {
  const iso = ts.includes('T') ? ts : `${ts.replace(' ', 'T')}Z`;
  return new Date(iso).getTime();
}

export function getFreshness(updatedAt: string | null | undefined): Freshness {
  if (!updatedAt) return 'offline';
  const ageMs = Date.now() - parseServerTimestamp(updatedAt);
  if (ageMs < LIVE_MS) return 'live';
  if (ageMs < STALE_MS) return 'stale';
  return 'offline';
}

export function relativeTime(updatedAt: string | null | undefined): string {
  if (!updatedAt) return 'never';
  const ageMs = Date.now() - parseServerTimestamp(updatedAt);
  if (ageMs < 0) return 'just now';
  const mins = Math.floor(ageMs / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

export const FRESHNESS_LABEL: Record<Freshness, string> = {
  live: 'Live',
  stale: 'Stale',
  offline: 'Offline',
};
