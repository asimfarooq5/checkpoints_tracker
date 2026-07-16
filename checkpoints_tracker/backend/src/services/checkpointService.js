import db from '../db.js';

export function getCheckpoints({ userId, status, assignedBy }) {
  let query = 'SELECT c.*, u.display_name AS user_name FROM checkpoints c JOIN users u ON c.user_id = u.id WHERE 1=1';
  const params = [];

  if (userId) { query += ' AND c.user_id = ?'; params.push(userId); }
  if (status) { query += ' AND c.status = ?'; params.push(status); }

  query += ' ORDER BY c.assigned_at DESC';
  return db.prepare(query).all(...params);
}

export function getCheckpointById(id) {
  return db.prepare(
    'SELECT c.*, u.display_name AS user_name FROM checkpoints c JOIN users u ON c.user_id = u.id WHERE c.id = ?'
  ).get(id);
}

export function createCheckpoint({ user_id, label, latitude, longitude }) {
  const result = db.prepare(
    'INSERT INTO checkpoints (user_id, label, latitude, longitude) VALUES (?, ?, ?, ?)'
  ).run(user_id, label, latitude, longitude);
  return getCheckpointById(result.lastInsertRowid);
}

export function updateCheckpoint(id, { label, latitude, longitude, user_id }) {
  const existing = db.prepare('SELECT * FROM checkpoints WHERE id = ?').get(id);
  if (!existing) return null;

  const updates = [];
  const values = [];

  if (label !== undefined) { updates.push('label = ?'); values.push(label); }
  if (latitude !== undefined) { updates.push('latitude = ?'); values.push(latitude); }
  if (longitude !== undefined) { updates.push('longitude = ?'); values.push(longitude); }
  if (user_id !== undefined) { updates.push('user_id = ?'); values.push(user_id); }

  if (updates.length === 0) return existing;

  values.push(id);
  db.prepare(`UPDATE checkpoints SET ${updates.join(', ')} WHERE id = ?`).run(...values);
  return getCheckpointById(id);
}

export function deleteCheckpoint(id) {
  const existing = db.prepare('SELECT id FROM checkpoints WHERE id = ?').get(id);
  if (!existing) return false;
  db.prepare('DELETE FROM checkpoints WHERE id = ?').run(id);
  return true;
}

export function markCheckpointCompleted(id) {
  const existing = db.prepare('SELECT * FROM checkpoints WHERE id = ?').get(id);
  if (!existing) return null;
  db.prepare(
    "UPDATE checkpoints SET status = 'completed', completed_at = datetime('now') WHERE id = ?"
  ).run(id);
  return getCheckpointById(id);
}

export function checkIn(id, latitude, longitude) {
  const existing = db.prepare('SELECT * FROM checkpoints WHERE id = ?').get(id);
  if (!existing) return null;
  const txn = db.transaction(() => {
    db.prepare(
      "UPDATE checkpoints SET last_latitude = ?, last_longitude = ?, last_checked_at = datetime('now') WHERE id = ?"
    ).run(latitude, longitude, id);
    db.prepare(
      'INSERT INTO checkin_log (user_id, checkpoint_id, latitude, longitude) VALUES (?, ?, ?, ?)'
    ).run(existing.user_id, id, latitude, longitude);
  });
  txn();
  return getCheckpointById(id);
}
