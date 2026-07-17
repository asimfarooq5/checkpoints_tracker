import Database from 'better-sqlite3';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import bcrypt from 'bcryptjs';
import 'dotenv/config';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const dbPath = path.resolve(__dirname, '..', process.env.DB_PATH || './data/checkpoints_tracker.db');
const dbDir = path.dirname(dbPath);

if (!fs.existsSync(dbDir)) {
  fs.mkdirSync(dbDir, { recursive: true });
}

const db = new Database(dbPath);

db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT    NOT NULL UNIQUE,
    password_hash TEXT    NOT NULL,
    display_name  TEXT    NOT NULL,
    role          TEXT    NOT NULL DEFAULT 'worker',
    latitude      REAL,
    longitude     REAL,
    alarm_enabled INTEGER NOT NULL DEFAULT 0,
    created_at    TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at    TEXT    NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS checkpoints (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id         INTEGER NOT NULL,
    label           TEXT    NOT NULL,
    latitude        REAL    NOT NULL,
    longitude       REAL    NOT NULL,
    status          TEXT    NOT NULL DEFAULT 'pending',
    assigned_at     TEXT    NOT NULL DEFAULT (datetime('now')),
    completed_at    TEXT,
    last_latitude   REAL,
    last_longitude  REAL,
    last_checked_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_checkpoints_user_id   ON checkpoints(user_id);
  CREATE INDEX IF NOT EXISTS idx_checkpoints_status    ON checkpoints(status);
  CREATE INDEX IF NOT EXISTS idx_checkpoints_user_status ON checkpoints(user_id, status);

  CREATE TABLE IF NOT EXISTS checkin_log (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id         INTEGER NOT NULL,
    checkpoint_id   INTEGER,
    latitude        REAL    NOT NULL,
    longitude       REAL    NOT NULL,
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_checkin_log_user ON checkin_log(user_id);
  CREATE INDEX IF NOT EXISTS idx_checkin_log_time ON checkin_log(created_at);
`);

// Add lat/long columns to existing users table if they don't exist (migration)
try { db.exec('ALTER TABLE users ADD COLUMN latitude REAL'); } catch {}
try { db.exec('ALTER TABLE users ADD COLUMN longitude REAL'); } catch {}
try { db.exec("ALTER TABLE users ADD COLUMN alarm_enabled INTEGER NOT NULL DEFAULT 0"); } catch {}
try { db.exec("ALTER TABLE users ADD COLUMN location_service_enabled INTEGER"); } catch {}
try { db.exec("ALTER TABLE users ADD COLUMN location_service_updated_at TEXT"); } catch {}

// Seed admin user if not exists
const adminUsername = process.env.ADMIN_USERNAME || 'admin';
const existingAdmin = db.prepare('SELECT id FROM users WHERE username = ?').get(adminUsername);

if (!existingAdmin) {
  const adminPassword = process.env.ADMIN_PASSWORD || 'admin123';
  const passwordHash = bcrypt.hashSync(adminPassword, 10);
  db.prepare(
    'INSERT INTO users (username, password_hash, display_name, role) VALUES (?, ?, ?, ?)'
  ).run(adminUsername, passwordHash, 'Administrator', 'admin');
  console.log(`Seeded admin user: ${adminUsername}`);
}

export default db;
