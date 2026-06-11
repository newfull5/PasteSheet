.PHONY: dev build lint check clean help

## Start development server (Tauri + Vite hot-reload)
dev:
	cargo tauri dev

## Build release binary
build:
	cargo tauri build

## Run Svelte type-check
lint:
	npm --prefix frontend run build -- --noEmit 2>/dev/null || \
	cd frontend && npx svelte-check --tsconfig ./tsconfig.json

## Run Clippy (Rust linter)
check:
	cd src-tauri && cargo clippy

## Remove build artifacts
clean:
	cd src-tauri && cargo clean
	rm -rf frontend/dist

## Show available commands
help:
	@echo ""
	@echo "  make dev    — Start dev server (Tauri + Vite)"
	@echo "  make build  — Build release binary"
	@echo "  make lint   — Svelte type-check"
	@echo "  make check  — Rust Clippy lint"
	@echo "  make clean  — Remove build artifacts"
	@echo ""
