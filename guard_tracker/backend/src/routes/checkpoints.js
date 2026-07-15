import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { adminMiddleware } from '../middleware/admin.js';
import { getUserLatLng } from '../services/userService.js';
import {
  getCheckpoints,
  getCheckpointById,
  createCheckpoint,
  updateCheckpoint,
  deleteCheckpoint,
  markCheckpointCompleted,
  checkIn,
} from '../services/checkpointService.js';

const router = Router();

router.use(authMiddleware);

// GET /api/checkpoints
router.get('/', (req, res) => {
  const { user_id, status } = req.query;
  // Workers can only see their own checkpoints
  const effectiveUserId = req.user.role === 'admin' ? user_id : req.user.id;
  const checkpoints = getCheckpoints({ userId: effectiveUserId || undefined, status: status || undefined });
  res.json({ checkpoints });
});

// GET /api/checkpoints/:id
router.get('/:id', (req, res) => {
  const cp = getCheckpointById(Number(req.params.id));
  if (!cp) return res.status(404).json({ error: 'Checkpoint not found' });
  if (req.user.role !== 'admin' && cp.user_id !== req.user.id) {
    return res.status(403).json({ error: 'Access denied' });
  }
  res.json({ checkpoint: cp });
});

// Admin-only routes
// POST /api/checkpoints
router.post('/', adminMiddleware, (req, res) => {
  const { user_id, label, latitude, longitude } = req.body;
  if (!user_id || !label) {
    return res.status(400).json({ error: 'user_id and label are required' });
  }

  let lat = latitude !== undefined ? Number(latitude) : undefined;
  let lng = longitude !== undefined ? Number(longitude) : undefined;

  // Inherit lat/long from user if not provided explicitly
  if (lat === undefined || lng === undefined) {
    const userLoc = getUserLatLng(user_id);
    if (!userLoc) return res.status(404).json({ error: 'User not found' });
    if (lat === undefined) lat = userLoc.latitude;
    if (lng === undefined) lng = userLoc.longitude;
  }

  if (lat === null || lng === null) {
    return res.status(400).json({ error: 'No coordinates available. Set lat/long on the user or provide them in the request.' });
  }

  const cp = createCheckpoint({ user_id, label, latitude: lat, longitude: lng });
  res.status(201).json({ checkpoint: cp });
});

// PUT /api/checkpoints/:id
router.put('/:id', adminMiddleware, (req, res) => {
  const { label, latitude, longitude, user_id } = req.body;
  const cp = updateCheckpoint(Number(req.params.id), { label, latitude, longitude, user_id });
  if (!cp) return res.status(404).json({ error: 'Checkpoint not found' });
  res.json({ checkpoint: cp });
});

// DELETE /api/checkpoints/:id
router.delete('/:id', adminMiddleware, (req, res) => {
  const deleted = deleteCheckpoint(Number(req.params.id));
  if (!deleted) return res.status(404).json({ error: 'Checkpoint not found' });
  res.json({ message: 'Checkpoint deleted' });
});

// PATCH /api/checkpoints/:id/status — worker marks as completed
router.patch('/:id/status', (req, res) => {
  const cp = getCheckpointById(Number(req.params.id));
  if (!cp) return res.status(404).json({ error: 'Checkpoint not found' });
  if (req.user.role !== 'admin' && cp.user_id !== req.user.id) {
    return res.status(403).json({ error: 'Access denied' });
  }
  const updated = markCheckpointCompleted(Number(req.params.id));
  res.json({ checkpoint: updated });
});

// PATCH /api/checkpoints/:id/checkin — worker sends current location
router.patch('/:id/checkin', (req, res) => {
  const { latitude, longitude } = req.body;
  if (latitude === undefined || longitude === undefined) {
    return res.status(400).json({ error: 'latitude and longitude are required' });
  }
  const cp = getCheckpointById(Number(req.params.id));
  if (!cp) return res.status(404).json({ error: 'Checkpoint not found' });
  if (req.user.role !== 'admin' && cp.user_id !== req.user.id) {
    return res.status(403).json({ error: 'Access denied' });
  }
  const updated = checkIn(Number(req.params.id), latitude, longitude);
  res.json({ checkpoint: updated });
});

export default router;
