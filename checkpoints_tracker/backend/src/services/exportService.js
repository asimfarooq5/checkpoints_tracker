export function toCsv(checkpoints) {
  const headers = ['id', 'user_id', 'user_name', 'label', 'latitude', 'longitude', 'status', 'assigned_at', 'completed_at', 'last_latitude', 'last_longitude', 'last_checked_at'];
  const rows = checkpoints.map(cp =>
    headers.map(h => {
      const val = cp[h] ?? '';
      // Escape CSV values containing commas or quotes
      const str = String(val);
      if (str.includes(',') || str.includes('"') || str.includes('\n')) {
        return `"${str.replace(/"/g, '""')}"`;
      }
      return str;
    }).join(',')
  );
  return headers.join(',') + '\n' + rows.join('\n');
}

export function toJson(checkpoints) {
  return JSON.stringify({ checkpoints }, null, 2);
}
