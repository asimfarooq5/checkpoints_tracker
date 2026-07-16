#!/usr/bin/env node
import bcrypt from 'bcryptjs';
import 'dotenv/config';
import db from './db.js';

const [,, cmd, ...args] = process.argv;

if (cmd === 'create-admin') {
  const username = args[0];
  const password = args[1];
  if (!username || !password) {
    console.error('Usage: node src/cli.js create-admin <username> <password>');
    process.exit(1);
  }

  const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
  if (existing) {
    // Update password if exists
    const hash = bcrypt.hashSync(password, 10);
    db.prepare("UPDATE users SET password_hash = ?, role = 'admin', updated_at = datetime('now') WHERE id = ?").run(hash, existing.id);
    console.log(`✓ Updated "${username}" to admin`);
  } else {
    const hash = bcrypt.hashSync(password, 10);
    db.prepare('INSERT INTO users (username, password_hash, display_name, role) VALUES (?, ?, ?, ?)').run(username, hash, username, 'admin');
    console.log(`✓ Created admin "${username}"`);
  }
} else if (cmd === 'list') {
  const users = db.prepare('SELECT id, username, role, created_at FROM users ORDER BY created_at DESC').all();
  console.table(users);
} else {
  console.log('Usage:');
  console.log('  node src/cli.js create-admin <username> <password>');
  console.log('  node src/cli.js list');
}
