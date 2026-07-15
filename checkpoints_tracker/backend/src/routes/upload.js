import { Router } from 'express';
import multer from 'multer';
import { authMiddleware } from '../middleware/auth.js';
import { adminMiddleware } from '../middleware/admin.js';
import { parseCsvBuffer, parseCsvRowsForUser } from '../services/csvService.js';
import db from '../db.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype === 'text/csv' || file.originalname.endsWith('.csv')) {
      cb(null, true);
    } else {
      cb(new Error('Only CSV files are allowed'));
    }
  },
});

const router = Router();

router.use(authMiddleware, adminMiddleware);

// POST /api/checkpoints/upload-csv — global CSV (username, label)
router.post('/checkpoints/upload-csv', upload.single('file'), (req, res) => {
  if (!req.file) {
    return res.status(400).json({ error: 'CSV file is required' });
  }

  const { rows, errors: parseErrors } = parseCsvBuffer(req.file.buffer);

  if (rows.length === 0) {
    return res.status(400).json({ imported: 0, errors: parseErrors });
  }

  const importErrors = [];
  let imported = 0;

  const insertStmt = db.prepare(
    'INSERT INTO checkpoints (user_id, label, latitude, longitude) VALUES (?, ?, ?, ?)'
  );
  const lookupUser = db.prepare('SELECT id, latitude, longitude FROM users WHERE username = ?');

  const transaction = db.transaction(() => {
    for (const row of rows) {
      const user = lookupUser.get(row.username);
      if (!user) {
        importErrors.push({ row: row.username, error: `User "${row.username}" not found` });
        continue;
      }
      if (user.latitude == null || user.longitude == null) {
        importErrors.push({ row: row.username, error: `User "${row.username}" has no lat/long assigned` });
        continue;
      }
      insertStmt.run(user.id, row.label, user.latitude, user.longitude);
      imported++;
    }
  });

  transaction();

  const allErrors = [...parseErrors, ...importErrors];
  res.json({ imported, errors: allErrors.length > 0 ? allErrors : undefined });
});

// POST /api/users/:userId/checkpoints/upload-csv — per-user CSV (label, latitude, longitude)
router.post('/users/:userId/checkpoints/upload-csv', upload.single('file'), (req, res) => {
  const userId = Number(req.params.userId);
  if (!req.file) {
    return res.status(400).json({ error: 'CSV file is required' });
  }

  const user = db.prepare('SELECT id, latitude, longitude FROM users WHERE id = ?').get(userId);
  if (!user) return res.status(404).json({ error: 'User not found' });

  const { rows, errors: parseErrors } = parseCsvRowsForUser(req.file.buffer);

  if (rows.length === 0) {
    return res.status(400).json({ imported: 0, errors: parseErrors });
  }

  let imported = 0;
  const insertStmt = db.prepare(
    'INSERT INTO checkpoints (user_id, label, latitude, longitude) VALUES (?, ?, ?, ?)'
  );

  const transaction = db.transaction(() => {
    for (const row of rows) {
      const lat = row.latitude ?? user.latitude;
      const lng = row.longitude ?? user.longitude;
      if (lat == null || lng == null) continue;
      insertStmt.run(userId, row.label, lat, lng);
      imported++;
    }
  });

  transaction();

  res.json({ imported, errors: parseErrors.length > 0 ? parseErrors : undefined });
});

export default router;
