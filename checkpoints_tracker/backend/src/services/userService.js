import db from '../db.js';
import { hashPassword } from './authService.js';

const USER_COLS = 'id, username, display_name, role, latitude, longitude, alarm_enabled, location_service_enabled, location_service_updated_at, created_at, updated_at';

export function getAllUsers() {
  return db.prepare(
    `SELECT ${USER_COLS} FROM users ORDER BY created_at DESC`
  ).all();
}

export function getUserById(id) {
  return db.prepare(
    `SELECT ${USER_COLS} FROM users WHERE id = ?`
  ).get(id);
}

export function getUserLatLng(id) {
  return db.prepare(
    'SELECT latitude, longitude FROM users WHERE id = ?'
  ).get(id);
}

export function createUser({ username, password, display_name, role = 'worker', latitude, longitude, alarm_enabled }) {
  const passwordHash = hashPassword(password);
  const result = db.prepare(
    'INSERT INTO users (username, password_hash, display_name, role, latitude, longitude, alarm_enabled) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).run(username, passwordHash, display_name, role, latitude ?? null, longitude ?? null, alarm_enabled ? 1 : 0);
  return getUserById(result.lastInsertRowid);
}

export function updateUser(id, { username, password, display_name, role, latitude, longitude, alarm_enabled }) {
  const existing = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
  if (!existing) return null;

  const updates = [];
  const values = [];

  if (username !== undefined) { updates.push('username = ?'); values.push(username); }
  if (display_name !== undefined) { updates.push('display_name = ?'); values.push(display_name); }
  if (role !== undefined) { updates.push('role = ?'); values.push(role); }
  if (latitude !== undefined) { updates.push('latitude = ?'); values.push(latitude); }
  if (longitude !== undefined) { updates.push('longitude = ?'); values.push(longitude); }
  if (alarm_enabled !== undefined) { updates.push('alarm_enabled = ?'); values.push(alarm_enabled ? 1 : 0); }
  if (password !== undefined && password !== '') {
    updates.push('password_hash = ?');
    values.push(hashPassword(password));
  }

  if (updates.length === 0) return existing;

  updates.push("updated_at = datetime('now')");
  values.push(id);

  db.prepare(`UPDATE users SET ${updates.join(', ')} WHERE id = ?`).run(...values);
  return getUserById(id);
}

export function deleteUser(id) {
  const existing = db.prepare('SELECT id FROM users WHERE id = ?').get(id);
  if (!existing) return false;
  db.prepare('DELETE FROM users WHERE id = ?').run(id);
  return true;
}
