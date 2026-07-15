import express from 'express';
import cors from 'cors';
import path from 'path';
import { fileURLToPath } from 'url';
import 'dotenv/config';

import authRoutes from './routes/auth.js';
import userRoutes from './routes/users.js';
import checkpointRoutes from './routes/checkpoints.js';
import uploadRoutes from './routes/upload.js';
import exportRoutes from './routes/export.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// API routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/checkpoints', checkpointRoutes);
app.use('/api', uploadRoutes);
app.use('/api/export', exportRoutes);

// Serve admin panel static files in production
const adminDist = path.resolve(__dirname, '..', 'admin-panel', 'dist');
app.use(express.static(adminDist));
app.get('*', (_req, res) => {
  res.sendFile(path.join(adminDist, 'index.html'));
});

// Error handling middleware
app.use((err, _req, res, _next) => {
  console.error('Unhandled error:', err);
  if (err.message?.includes('Only CSV files')) {
    return res.status(400).json({ error: err.message });
  }
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(400).json({ error: 'File too large. Max 5MB.' });
  }
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://0.0.0.0:${PORT}`);
});
