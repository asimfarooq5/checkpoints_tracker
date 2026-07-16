import { Router } from 'express';
import { authMiddleware } from '../middleware/auth.js';
import { adminMiddleware } from '../middleware/admin.js';
import { getAllUsers, getUserById, createUser, updateUser, deleteUser } from '../services/userService.js';

const router = Router();

router.use(authMiddleware, adminMiddleware);

// GET /api/users
router.get('/', (_req, res) => {
  const users = getAllUsers();
  res.json({ users });
});

// GET /api/users/:id
router.get('/:id', (req, res) => {
  const user = getUserById(Number(req.params.id));
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json({ user });
});

// POST /api/users
router.post('/', (req, res) => {
  const { username, password, display_name, role, latitude, longitude, alarm_enabled } = req.body;
  if (!username || !password || !display_name) {
    return res.status(400).json({ error: 'username, password, and display_name are required' });
  }
  try {
    const user = createUser({
      username,
      password,
      display_name,
      role,
      latitude: latitude !== undefined ? Number(latitude) : undefined,
      longitude: longitude !== undefined ? Number(longitude) : undefined,
      alarm_enabled,
    });
    res.status(201).json({ user });
  } catch (err) {
    if (err.message?.includes('UNIQUE constraint')) {
      return res.status(409).json({ error: 'Username already exists' });
    }
    throw err;
  }
});

// PUT /api/users/:id
router.put('/:id', (req, res) => {
  const { username, password, display_name, role, latitude, longitude, alarm_enabled } = req.body;
  const user = updateUser(Number(req.params.id), {
    username,
    password,
    display_name,
    role,
    latitude: latitude !== undefined ? Number(latitude) : undefined,
    longitude: longitude !== undefined ? Number(longitude) : undefined,
    alarm_enabled,
  });
  if (!user) return res.status(404).json({ error: 'User not found' });
  res.json({ user });
});

// DELETE /api/users/:id
router.delete('/:id', (req, res) => {
  const deleted = deleteUser(Number(req.params.id));
  if (!deleted) return res.status(404).json({ error: 'User not found' });
  res.json({ message: 'User deleted' });
});

export default router;
