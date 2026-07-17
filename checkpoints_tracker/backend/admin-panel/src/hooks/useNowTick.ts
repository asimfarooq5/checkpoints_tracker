import { useEffect, useState } from 'react';

// Forces a re-render every `intervalMs` so time-relative UI (freshness badges,
// "Xm ago" labels) updates smoothly between data fetches instead of only
// jumping when new data actually arrives — otherwise a Live->Stale transition
// sits stale-looking until the next poll happens to land after the threshold.
export function useNowTick(intervalMs = 5000): number {
  const [tick, setTick] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setTick(t => t + 1), intervalMs);
    return () => clearInterval(id);
  }, [intervalMs]);
  return tick;
}
