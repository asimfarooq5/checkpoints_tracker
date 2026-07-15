import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import 'dotenv/config';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';

export function hashPassword(plain) {
  return bcrypt.hashSync(plain, 10);
}

export function verifyPassword(plain, hash) {
  return bcrypt.compareSync(plain, hash);
}

export function signToken(user) {
  return jwt.sign(
    { id: user.id, username: user.username, role: user.role, display_name: user.display_name },
    JWT_SECRET,
    { expiresIn: '24h' }
  );
}
