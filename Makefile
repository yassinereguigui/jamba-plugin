# jamba-plugin — developer + CI entry points.
# Every check runs the same way locally and in CI. Keep this file as the single
# source of truth for "what the gate checks".

.DEFAULT_GOAL := help
PLUGIN_DIR := .

.PHONY: help validate

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "} {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

validate: ## Structural gate: claude plugin validate --strict
	claude plugin validate $(PLUGIN_DIR) --strict
