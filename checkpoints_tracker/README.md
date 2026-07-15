# Checkpoints Tracker

Field worker checkpoint tracking system. Admin panel for management, Flutter app for field workers with background location check-ins.

## Quick Start

```bash
# Prerequisites: Node.js 20+, Flutter SDK
git clone git@github.com:asimfarooq5/checkpoints_tracker.git
cd checkpoints_tracker
```

### Backend + Admin Panel

```bash
cd backend
npm install
cd admin-panel && npm install && npm run build && cd ..
cp .env .env.local   # edit JWT_SECRET, ADMIN_PASSWORD, DB_PATH
node src/index.js    # runs on http://0.0.0.0:3000
```

Or with make:

```bash
make install   # install all deps
make build     # build admin panel
make backend   # start server
```

Default admin login: `admin` / `admin123`.

### Flutter App

```bash
cd flutter_app
flutter pub get
flutter run
```

Update `lib/config/api_config.dart` with your server's IP before building.

## Project Structure

```
checkpoints_tracker/
├── backend/
│   ├── src/
│   │   ├── index.js            ← Express server
│   │   ├── db.js               ← SQLite schema + seed
│   │   ├── routes/             ← Auth, Users, Checkpoints, Upload, Export
│   │   ├── services/           ← Business logic
│   │   └── middleware/         ← JWT auth, Admin guard
│   └── admin-panel/            ← React SPA (Vite)
│       └── src/pages/          ← Login, Users, Dashboard, Checkpoints
├── flutter_app/                ← Mobile app
│   └── lib/
│       ├── screens/            ← Login, Home, Checkpoint Detail, Permissions
│       ├── services/           ← API, Auth, Checkpoint, Foreground, Background
│       ├── providers/          ← State management
│       └── models/             ← User, Checkpoint
└── Makefile
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/login` | Login |
| GET | `/api/auth/me` | Current user |
| GET/POST/PUT/DELETE | `/api/users` | User CRUD (admin) |
| GET/POST/PUT/DELETE | `/api/checkpoints` | Checkpoint CRUD |
| PATCH | `/api/checkpoints/:id/status` | Mark completed |
| PATCH | `/api/checkpoints/:id/checkin` | Location check-in |
| POST | `/api/checkpoints/upload-csv` | Bulk CSV import |
| POST | `/api/users/:userId/checkpoints/upload-csv` | Per-user CSV import |
| GET | `/api/export/users/:userId/checkpoints` | Export |

## Tech Stack

- **Backend:** Node.js, Express, better-sqlite3, JWT
- **Admin UI:** React, TypeScript, Vite
- **Mobile:** Flutter, Provider, WorkManager, Background Service
- **Permissions:** Location (foreground + background), Notifications (ongoing)
