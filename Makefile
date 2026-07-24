# jamba-plugin — developer + CI entry points.
# Every check runs the same way locally and in CI. Keep this file as the single
# source of truth for "what the gate checks".

.DEFAULT_GOAL := help
PLUGIN_DIR := .

.PHONY: help check validate json frontmatter hygiene

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

check: validate json frontmatter hygiene ## Run the full deterministic gate

validate: ## Structural gate: claude plugin validate --strict
	claude plugin validate $(PLUGIN_DIR) --strict

json: ## Every JSON file parses
	@fail=0; \
	for f in $$(find . -name '*.json' -not -path './.git/*' -not -path './.cache/*' -not -path '*/node_modules/*' | sort); do \
		if jq empty "$$f" >/dev/null 2>&1; then echo "  ok   $$f"; \
		else echo "  FAIL $$f"; jq empty "$$f" || true; fail=1; fi; \
	done; \
	exit $$fail

frontmatter: ## Skills/agents declare required frontmatter
	@./scripts/check-frontmatter.sh

hygiene: ## No OS/editor junk files tracked
	@./scripts/check-hygiene.sh
