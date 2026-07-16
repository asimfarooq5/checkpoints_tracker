export type Freshness = 'live' | 'stale' | 'offline';

const LIVE_MS = 2 * 60 * 1000;
const STALE_MS = 15 * 60 * 1000;

export function getFreshness(updatedAt: string | null | undefined): Freshness {
  if (!updatedAt) return 'offline';
  const ageMs = Date.now() - new Date(updatedAt).getTime();
  if (ageMs < LIVE_MS) return 'live';
  if (ageMs < STALE_MS) return 'stale';
  return 'offline';
}

export function relativeTime(updatedAt: string | null | undefined): string {
  if (!updatedAt) return 'never';
  const ageMs = Date.now() - new Date(updatedAt).getTime();
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
