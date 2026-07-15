ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
NVIM ?= nvim

.PHONY: deps test check-shell check

deps:
	@if git -C "$(ROOT)" ls-files --error-unmatch deps/mini.test >/dev/null 2>&1; then \
		git -C "$(ROOT)" submodule update --init --depth 1 --checkout deps/mini.test; \
	else \
		test -f "$(ROOT)/deps/mini.test/lua/mini/test.lua"; \
	fi

test: deps
	cd "$(ROOT)" && "$(NVIM)" --headless --noplugin -i NONE \
		-u "$(ROOT)/scripts/minimal_init.lua" -c "lua MiniTest.run()"

check-shell:
	bash -n "$(ROOT)/scripts/herdr-nav.sh"
	bash -n "$(ROOT)/scripts/herdr-resize.sh"

check: check-shell test
