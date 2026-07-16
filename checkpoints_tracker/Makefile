BACKEND_DIR := backend
ADMIN_DIR := $(BACKEND_DIR)/admin-panel
FLUTTER_DIR := flutter_app

.PHONY: all backend admin flutter build clean help docker docker-up docker-down docker-rebuild

all: build

# ── Backend (API + built admin panel) ──────────────────────────

backend: $(ADMIN_DIR)/dist
	@echo "→ Starting backend on http://localhost:3000"
	cd $(BACKEND_DIR) && node src/index.js

# ── Admin panel dev server (hot reload) ─────────────────────────

admin:
	@echo "→ Starting admin panel dev server on http://localhost:5173"
	cd $(ADMIN_DIR) && npx vite --host

# ── Flutter app ─────────────────────────────────────────────────

flutter:
	@echo "→ Running Flutter app"
	cd $(FLUTTER_DIR) && flutter run

# ── Build admin panel ───────────────────────────────────────────

$(ADMIN_DIR)/dist: $(ADMIN_DIR)/src $(ADMIN_DIR)/package.json
	@echo "→ Building admin panel..."
	cd $(ADMIN_DIR) && npm run build
	@echo "✓ Built to admin-panel/dist/"

build: $(ADMIN_DIR)/dist

# ── Install dependencies ────────────────────────────────────────

install: install-backend install-admin

install-backend:
	@echo "→ Installing backend dependencies..."
	cd $(BACKEND_DIR) && npm install

install-admin:
	@echo "→ Installing admin panel dependencies..."
	cd $(ADMIN_DIR) && npm install

install-flutter:
	@echo "→ Getting Flutter dependencies..."
	cd $(FLUTTER_DIR) && flutter pub get

# ── Clean ──────────────────────────────────────────────────────

clean:
	@echo "→ Cleaning build artifacts..."
	rm -rf $(ADMIN_DIR)/dist
	@echo "✓ Cleaned"

distclean: clean
	@echo "→ Removing node_modules..."
	rm -rf $(BACKEND_DIR)/node_modules
	rm -rf $(ADMIN_DIR)/node_modules
	rm -rf $(BACKEND_DIR)/data
	@echo "✓ Everything cleaned"

# ── Help ────────────────────────────────────────────────────────

# ── CLI ──────────────────────────────────────────────────────────

cli:
	@echo "Usage: make cli-create-admin <username> <password>"
	@echo "       make cli-list"

cli-create-admin:
	cd $(BACKEND_DIR) && node src/cli.js create-admin $(filter-out $@,$(MAKECMDGOALS))

cli-list:
	cd $(BACKEND_DIR) && node src/cli.js list

# ── Docker ──────────────────────────────────────────────────────

docker:
	docker compose build
	docker compose up -d
	@echo "→ Backend running on http://0.0.0.0:3300"

docker-up:
	docker compose up -d --build
	@echo "→ Backend running on http://0.0.0.0:3300"

docker-pull:
	git pull
	docker compose up -d --build
	@echo "→ Updated & restarted"

docker-down:
	docker compose down

docker-rebuild:
	docker compose build --no-cache
	docker compose up -d

# ── Help ────────────────────────────────────────────────────────

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  backend       Start production server (API + admin UI) on :3000"
	@echo "  admin         Start admin panel dev server on :5173 (hot reload)"
	@echo "  flutter       Run Flutter app on connected device/emulator"
	@echo "  build         Rebuild admin panel static files"
	@echo "  install       Install all dependencies (backend + admin)"
	@echo "  clean         Remove build artifacts"
	@echo "  distclean     Remove build artifacts + node_modules + data"
	@echo "  docker        Build & start in Docker container"
	@echo "  docker-up     Start existing Docker container (rebuilds if needed)"
	@echo "  docker-down   Stop Docker container"
	@echo "  docker-rebuild Force rebuild Docker image from scratch"
	@echo "  docker-pull   Git pull + rebuild + restart"
