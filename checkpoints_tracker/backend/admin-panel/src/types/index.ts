export interface User {
  id: number;
  username: string;
  display_name: string;
  role: 'admin' | 'worker';
  latitude: number | null;
  longitude: number | null;
  alarm_enabled: number;
  created_at: string;
  updated_at: string;
}

export interface WorkerLocation {
  id: number;
  username: string;
  display_name: string;
  location: { latitude: number; longitude: number; updated_at: string } | null;
}

export interface Checkpoint {
  id: number;
  user_id: number;
  user_name?: string;
  label: string;
  latitude: number;
  longitude: number;
  status: 'pending' | 'completed';
  assigned_at: string;
  completed_at: string | null;
  last_latitude: number | null;
  last_longitude: number | null;
  last_checked_at: string | null;
}
