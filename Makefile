.PHONY: lint lint-fix eval-all help

SKILLSAW_IMAGE := ghcr.io/stbenjam/skillsaw:latest

lint:
	@docker run --rm -v "$$(pwd):/workspace:Z" $(SKILLSAW_IMAGE) lint --strict $(SKILLSAW_ARGS)

lint-fix:
	@docker run --rm -v "$$(pwd):/workspace:Z" $(SKILLSAW_IMAGE) fix

eval-all:
	@found=0; \
	for f in $$(find .claude/skills -name "evals.json" -type f 2>/dev/null); do \
		found=1; \
		echo "=== Running: $$f ==="; \
		./run_evals.sh "$$f"; \
	done; \
	if [ "$$found" = "0" ]; then echo "No eval files found"; fi

help:
	@echo "Available targets:"
	@echo "  lint           - Run skillsaw linter (Docker)"
	@echo "  lint-fix       - Auto-fix fixable issues"
	@echo "  eval-all       - Run all skill evals"
	@echo "  help           - Show this help"
