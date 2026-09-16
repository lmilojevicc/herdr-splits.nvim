ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
NVIM ?= nvim
PWSH ?= pwsh

.PHONY: deps test check-shell check-powershell test-shell test-powershell check check-windows

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

# Syntax-only gate for the Windows ports, mirroring check-shell.
check-powershell:
	$(PWSH) -NoProfile -NonInteractive -File "$(ROOT)/tests/shell/check_powershell.ps1"

test-powershell:
	$(PWSH) -NoProfile -NonInteractive -File "$(ROOT)/tests/shell/test_vim_name.ps1"

test-shell:
	bash "$(ROOT)/tests/shell/test_vim_name.sh"

check: check-shell test-shell test

# The Windows-side gates. Kept out of `check` so a POSIX contributor
# without PowerShell installed can still run it; CI runs both.
check-windows: check-powershell test-powershell
