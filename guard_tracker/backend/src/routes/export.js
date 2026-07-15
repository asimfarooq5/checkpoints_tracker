import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { adminMiddleware } from '../middleware/admin.js';
import db from '../db.js';
import { toCsv, toJson } from '../services/exportService.js';

const router = Router();

router.use(authMiddleware, adminMiddleware);

// GET /api/export/users/:userId/checkpoints?format=csv|json
router.get('/users/:userId/checkpoints', (req, res) => {
  const userId = Number(req.params.userId);
  const format = req.query.format || 'json';

  const user = db.prepare('SELECT id, username, display_name FROM users WHERE id = ?').get(userId);
  if (!user) {
    return res.status(404).json({ error: 'User not found' });
  }

  const checkpoints = db.prepare(
    'SELECT c.*, u.display_name AS user_name FROM checkpoints c JOIN users u ON c.user_id = u.id WHERE c.user_id = ? ORDER BY c.assigned_at DESC'
  ).all(userId);

  if (format === 'csv') {
    const csv = toCsv(checkpoints);
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename="checkpoints-${user.username}.csv"`);
    res.send(csv);
  } else {
    const json = toJson(checkpoints);
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Content-Disposition', `attachment; filename="checkpoints-${user.username}.json"`);
    res.send(json);
  }
});

// GET /api/export/all?format=csv|json
router.get('/all', (req, res) => {
  const format = req.query.format || 'json';
  const checkpoints = db.prepare(
    'SELECT c.*, u.display_name AS user_name FROM checkpoints c JOIN users u ON c.user_id = u.id ORDER BY u.username, c.assigned_at DESC'
  ).all();

  if (format === 'csv') {
    const csv = toCsv(checkpoints);
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="all-checkpoints.csv"');
    res.send(csv);
  } else {
    res.json({ checkpoints });
  }
});

export default router;
