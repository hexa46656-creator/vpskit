REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: verify-architecture ci-simulate static-validate

verify-architecture:
	bash "$(REPO_ROOT)/scripts/static_validate.sh"

ci-simulate:
	bash "$(REPO_ROOT)/scripts/ci_simulate.sh"

static-validate:
	bash "$(REPO_ROOT)/scripts/static_validate.sh"
