.PHONY: dev run build test

dev:
	@if ! command -v watchexec >/dev/null 2>&1; then \
		echo "watchexec not found. Install with: brew install watchexec"; \
		exit 1; \
	fi
	watchexec -w Sources -w Tests -w Package.swift -w Makefile --restart -- swift run AIAgentLaunch

run:
	swift run AIAgentLaunch

build:
	swift build

test:
	swift test
