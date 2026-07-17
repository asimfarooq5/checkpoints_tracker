import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { adminMiddleware } from '../middleware/admin.js';
import db from '../db.js';

const router = Router();

// POST /api/location — worker pushes their current location (no checkpoint needed)
router.post('/location', authMiddleware, (req, res) => {
  const { latitude, longitude } = req.body;
  if (latitude === undefined || longitude === undefined) {
    return res.status(400).json({ error: 'latitude and longitude are required' });
  }
  db.prepare(
    'INSERT INTO checkin_log (user_id, checkpoint_id, latitude, longitude) VALUES (?, ?, ?, ?)'
  ).run(req.user.id, null, latitude, longitude);
  res.json({ message: 'ok' });
});

// PATCH /api/location/status — worker reports whether device location services are on/off.
// Separate from POST /location: when location is OFF the app has no coordinates to send,
// but the admin should still find out immediately rather than inferring it from staleness.
router.patch('/location/status', authMiddleware, (req, res) => {
  const { enabled } = req.body;
  if (typeof enabled !== 'boolean') {
    return res.status(400).json({ error: 'enabled (boolean) is required' });
  }
  db.prepare(
    "UPDATE users SET location_service_enabled = ?, location_service_updated_at = datetime('now') WHERE id = ?"
  ).run(enabled ? 1 : 0, req.user.id);
  res.json({ message: 'ok' });
});

// GET /api/location/trail/:userId — full route trail for a worker
router.get('/location/trail/:userId', authMiddleware, (req, res) => {
  const userId = Number(req.params.userId);
  if (req.user.role !== 'admin' && req.user.id !== userId) {
    return res.status(403).json({ error: 'Access denied' });
  }

  const points = db.prepare(`
    SELECT latitude, longitude, created_at, checkpoint_id
    FROM checkin_log
    WHERE user_id = ?
    ORDER BY created_at ASC
  `).all(userId);

  res.json({ user_id: userId, points });
});

// DELETE /api/location/trail/:userId — clear a worker's location trail (admin only)
router.delete('/location/trail/:userId', authMiddleware, adminMiddleware, (req, res) => {
  const userId = Number(req.params.userId);
  const user = db.prepare('SELECT id FROM users WHERE id = ?').get(userId);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const result = db.prepare('DELETE FROM checkin_log WHERE user_id = ?').run(userId);
  res.json({ message: 'ok', deleted: result.changes });
});

// GET /api/users/:userId/location — latest known location for a worker
router.get('/users/:userId/location', authMiddleware, adminMiddleware, (req, res) => {
  const userId = Number(req.params.userId);
  const user = db.prepare(
    'SELECT id, username, display_name, location_service_enabled, location_service_updated_at FROM users WHERE id = ?'
  ).get(userId);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const latest = db.prepare(`
    SELECT latitude, longitude, created_at
    FROM checkin_log
    WHERE user_id = ?
    ORDER BY created_at DESC
    LIMIT 1
  `).get(userId);

  if (!latest) {
    return res.json({ user, location: null, message: 'No location data yet.' });
  }

  res.json({
    user,
    location: { latitude: latest.latitude, longitude: latest.longitude, updated_at: latest.created_at },
  });
});

// GET /api/locations — all workers' latest locations
router.get('/locations', authMiddleware, adminMiddleware, (req, res) => {
  const workers = db.prepare(
    "SELECT id, username, display_name, location_service_enabled, location_service_updated_at FROM users WHERE role = 'worker'"
  ).all();

  const result = workers.map(worker => {
    const latest = db.prepare(`
      SELECT latitude, longitude, created_at
      FROM checkin_log
      WHERE user_id = ?
      ORDER BY created_at DESC
      LIMIT 1
    `).get(worker.id);

    return {
      ...worker,
      location: latest
        ? { latitude: latest.latitude, longitude: latest.longitude, updated_at: latest.created_at }
        : null,
    };
  });

  res.json({ workers: result });
});

export default router;
